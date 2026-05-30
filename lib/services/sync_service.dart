import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import 'cactus_local_service.dart';
import '../models/user_level.dart';
import '../models/word.dart';

import '../providers/connectivity_provider.dart';

enum SyncStatus { idle, syncing, completed, error }

enum SyncError { none, notConfigured, localModelMissing, networkError, unknown }

class SyncProgress {
  final int processed;
  final int total;
  SyncProgress({required this.processed, required this.total});
  double get percentage => total > 0 ? processed / total : 0.0;
}

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal() {
    _init();
  }

  void _init() {
    ConnectivityChecker.instance.connectivityStream.listen((isOnline) {
      if (isOnline) {
        print('SyncService: Connectivity restored. Triggering sync...');
        processPendingQueue();
      }
    });
  }

  final _statusCtrl = StreamController<SyncStatus>.broadcast();
  final _progressCtrl = StreamController<SyncProgress>.broadcast();

  Stream<SyncStatus> get syncStatusStream => _statusCtrl.stream;
  Stream<SyncProgress> get syncProgressStream => _progressCtrl.stream;

  bool _isSyncing = false;
  bool _isCancelled = false;
  bool get isSyncing => _isSyncing;
  SyncError lastError = SyncError.none;
  String? lastErrorMessage;

  void cancelSync() {
    if (_isSyncing) {
      _isCancelled = true;
      final cactus = CactusLocalService();
      if (cactus.isGenerating) {
        cactus.cancelGeneration();
      }
      print('SyncService: Sync cancellation requested.');
    }
  }

  // ─── Main entry point ─────────────────────────────────────────────────────

  Future<void> processPendingQueue() async {
    if (_isSyncing) {
      print('SyncService: Already syncing, skipping.');
      return;
    }
    _isSyncing = true;
    _statusCtrl.add(SyncStatus.syncing);

    try {
      lastError = SyncError.none;
      final provider =
          await DatabaseService.instance.getSetting('ai_provider') ?? 'gemini';
      final localModelId =
          await DatabaseService.instance.getSetting('cactus_model_id') ??
              CactusLocalService.defaultModelId;
      print(
          'SyncService: Starting sync with provider=$provider localModel=$localModelId');

      // Build AIService with keys from DB, fallback to .env
      final aiService = await _buildAIService();

      final queue = await DatabaseService.instance.getPendingQueue();
      print('SyncService: ${queue.length} item(s) in pending queue.');

      if (queue.isEmpty) {
        _statusCtrl.add(SyncStatus.completed);
        return;
      }

      if (provider == 'cactus') {
        final modelPath = await CactusLocalService().getModelPath(localModelId);
        final modelDir = Directory(modelPath);
        if (!await modelDir.exists()) {
          print('SyncService: Cactus model not found at $modelPath. '
              'Go to Settings > AI Provider to download it.');
          lastError = SyncError.localModelMissing;
          _statusCtrl.add(SyncStatus.error);
          return;
        }
      }

      await _prewarmSelectedModel(provider, localModelId);

      if (!aiService.isConfigured) {
        print('SyncService: AIService is not configured. Aborting.');
        lastError = SyncError.notConfigured;
        _statusCtrl.add(SyncStatus.error);
        return;
      }

      _progressCtrl.add(SyncProgress(processed: 0, total: queue.length));

      int processedCount = 0;
      int totalFailCount = 0;
      int retryPass = 0;

      while (true) {
        if (_isCancelled) {
          print(
              'SyncService: Sync cancelled. Processed $processedCount/${queue.length} before cancellation.');
          break;
        }

        final currentQueue = await DatabaseService.instance.getPendingQueue();
        if (currentQueue.isEmpty) {
          print('SyncService: Queue is empty.');
          break;
        }

        final processable = currentQueue.where((item) {
          final retry = (item['retry_count'] as int?) ?? 0;
          return retry < 3;
        }).toList();

        if (processable.isEmpty) {
          print('SyncService: All remaining items exceed max retries.');
          break;
        }

        _progressCtrl
            .add(SyncProgress(processed: processedCount, total: queue.length));

        int passFailCount = 0;

        for (final item in processable) {
          if (_isCancelled) break;

          final wordId = item['word_id'] as String;
          final retryCount = (item['retry_count'] as int?) ?? 0;

          _progressCtrl.add(
              SyncProgress(processed: processedCount, total: queue.length));
          await Future.delayed(Duration.zero);

          try {
            final success = await _processItem(wordId, aiService, retryCount);
            if (success) {
              processedCount++;
            } else {
              passFailCount++;
            }
          } catch (e) {
            print('SyncService: Exception on word $wordId: $e');
            await _incrementRetry(wordId);
            passFailCount++;
          }

          _progressCtrl.add(
              SyncProgress(processed: processedCount, total: queue.length));
          await Future.delayed(Duration.zero);
        }

        totalFailCount += passFailCount;

        if (passFailCount == 0) {
          break;
        }

        retryPass++;
        final backoff = Duration(seconds: min(pow(2, retryPass).toInt(), 30));
        print(
            'SyncService: $passFailCount item(s) failed, retry pass $retryPass. '
            'Waiting ${backoff.inSeconds}s...');
        await Future.delayed(backoff);
      }

      if (_isCancelled) {
        print('SyncService: Sync was cancelled by user.');
        _statusCtrl.add(SyncStatus.idle);
      } else if (totalFailCount > 0 && provider == 'cactus') {
        lastError = SyncError.localModelMissing;
        lastErrorMessage = '$totalFailCount word(s) failed to generate. '
            'The Cactus model may have produced invalid output. '
            'Check logs or try Gemini/OpenAI.';
        print('SyncService: $totalFailCount Cactus item(s) failed.');
      }

      print(
          'SyncService: Done. $processedCount/${queue.length} processed successfully.');
      _statusCtrl.add(SyncStatus.completed);
    } catch (e) {
      print('SyncService: Fatal error: $e');
      final errStr = e.toString();
      if (errStr.contains('Connection') || errStr.contains('SocketException')) {
        lastError = SyncError.networkError;
      } else {
        lastError = SyncError.unknown;
      }
      _statusCtrl.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
      _isCancelled = false;
    }
  }

  /// Re-queues ALL words that have no summary so they can be retried.
  /// This handles both words that failed silently and words stuck after max retries.
  Future<void> resetFailedWords() async {
    final words = await DatabaseService.instance.getWords();
    final queue = await DatabaseService.instance.getPendingQueue();
    final queuedIds = queue.map((e) => e['word_id'] as String).toSet();

    int resetCount = 0;
    for (final word in words) {
      // Re-queue any word without a summary, regardless of isPending status
      // This catches words that hit max retries and were removed from queue
      if (word.summary == null && !queuedIds.contains(word.id)) {
        await DatabaseService.instance.updateWord(
          word.copyWith(isPending: true, updatedAt: DateTime.now()),
        );
        await DatabaseService.instance.addToQueue(word.id);
        resetCount++;
      }
    }

    print(
        'SyncService: Re-queued $resetCount word(s) without summaries. Starting queue processing...');
    processPendingQueue();
  }

  // ─── Build AIService ──────────────────────────────────────────────────────

  Future<AIService> _buildAIService() async {
    final provider =
        await DatabaseService.instance.getSetting('ai_provider') ?? 'gemini';
    final localModel =
        await DatabaseService.instance.getSetting('cactus_model_id') ??
            CactusLocalService.defaultModelId;
    // Key names must match what settings_provider.dart uses to save them
    String? openAIKey = await DatabaseService.instance.getSetting('openai_key');
    String? geminiKey = await DatabaseService.instance.getSetting('gemini_key');

    // Fallback to .env
    if (openAIKey == null || openAIKey.isEmpty) {
      openAIKey = dotenv.env['OPENAI_API_KEY'];
    }
    if (geminiKey == null || geminiKey.isEmpty) {
      geminiKey = dotenv.env['GEMINI_API_KEY'];
    }

    final activeKey = (provider == 'gemini' ? geminiKey : openAIKey) ?? '';
    final keyPreview = activeKey.length > 8
        ? '${activeKey.substring(0, 4)}...${activeKey.substring(activeKey.length - 4)}'
        : (activeKey.isEmpty ? 'none' : 'short/invalid');

    print(
        'SyncService: provider=$provider localModel=$localModel activeKey=$keyPreview');

    final service = AIService();
    service.configure(
      openAIKey: openAIKey,
      geminiKey: geminiKey,
      provider: provider,
      localModelId: localModel,
    );
    return service;
  }

  // ─── Process single item ─────────────────────────────────────────────────

  /// Returns true if successfully processed (summary saved or item cleaned up).
  Future<bool> _processItem(
      String wordId, AIService aiService, int retryCount) async {
    final word = await DatabaseService.instance.getWord(wordId);
    if (word == null) {
      // Orphaned queue entry – remove it
      await DatabaseService.instance.removeFromQueue(wordId);
      return true;
    }

    if (retryCount >= 3) {
      print(
          'SyncService: Max retries ($retryCount) for "${word.text}". Marking as not-pending.');
      await DatabaseService.instance.updateWord(
        word.copyWith(isPending: false, updatedAt: DateTime.now()),
      );
      await DatabaseService.instance.removeFromQueue(wordId);
      return true;
    }

    // Exponential back-off on retries
    if (retryCount > 0) {
      final wait = Duration(seconds: pow(2, retryCount).toInt());
      print(
          'SyncService: Retry $retryCount – waiting ${wait.inSeconds}s for "${word.text}".');
      await Future.delayed(wait);
    }

    print('SyncService: Requesting summary for "${word.text}"...');
    final isLocal =
        await DatabaseService.instance.getSetting('ai_provider') == 'cactus';
    final summary = await aiService.generateSummary(
      word: word.text,
      context: word.context,
      level: UserLevel.beginner,
      keepAlive: isLocal && retryCount < 2,
    );

    if (summary != null) {
      final enrichedSummary = await _withLibrarySimilarWords(word, summary);
      await DatabaseService.instance.updateWord(
        word.copyWith(
            summary: enrichedSummary,
            isPending: false,
            updatedAt: DateTime.now()),
      );
      await DatabaseService.instance.removeFromQueue(wordId);
      print('SyncService: ✓ Summary saved for "${word.text}".');
      return true;
    } else {
      await _incrementRetry(wordId);
      print(
          'SyncService: ✗ Summary failed for "${word.text}" (retry ${retryCount + 1}).');
      return false;
    }
  }

  Future<void> _incrementRetry(String wordId) async {
    final db = await DatabaseService.instance.database;
    await db.rawUpdate(
      'UPDATE pending_queue SET retry_count = retry_count + 1 WHERE word_id = ?',
      [wordId],
    );
  }

  Future<void> dispose() async {
    _statusCtrl.close();
    _progressCtrl.close();
  }

  Future<void> _prewarmSelectedModel(String provider, String modelId) async {
    if (provider == 'cactus') {
      final result = await CactusLocalService().initialize(modelId);
      if (!result.isSuccess) {
        print('SyncService: Cactus prewarm skipped: ${result.message}');
      } else {
        print('SyncService: Cactus model prewarmed: $modelId');
      }
    }
  }

  Future<WordSummary> _withLibrarySimilarWords(
    Word word,
    WordSummary summary,
  ) async {
    final libraryWords = await DatabaseService.instance.getWords();
    final candidates = <String>[];
    final current = word.text.trim().toLowerCase();

    for (final savedWord in libraryWords) {
      final text = savedWord.text.trim();
      if (text.isEmpty || text.toLowerCase() == current) continue;

      final existingSummary = savedWord.summary;
      final haystack = [
        savedWord.text,
        existingSummary?.definition ?? '',
        existingSummary?.mainSay ?? '',
        ...?existingSummary?.similarWords,
      ].join(' ').toLowerCase();

      final generatedSimilar =
          summary.similarWords.map((item) => item.toLowerCase()).toSet();
      if (generatedSimilar.contains(text.toLowerCase()) ||
          summary.definition.toLowerCase().contains(text.toLowerCase()) ||
          haystack.contains(current)) {
        candidates.add(text);
      }
    }

    final merged = <String>[];
    final seen = <String>{};
    for (final item in [...candidates, ...summary.similarWords]) {
      final normalized = item.trim().toLowerCase();
      if (normalized.isEmpty ||
          normalized == current ||
          seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      merged.add(item.trim());
      if (merged.length >= 5) break;
    }

    if (merged.isEmpty) return summary;

    return WordSummary(
      definition: summary.definition,
      mainSay: summary.mainSay,
      useCases: summary.useCases,
      similarWords: merged,
      detailedSummary: summary.detailedSummary,
      generatedAt: summary.generatedAt,
    );
  }
}

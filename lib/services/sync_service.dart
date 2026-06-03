import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'analytics_service.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import 'app_logger.dart';
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
        AppLogger.info('SyncService: Connectivity restored. Triggering sync...');
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
      AppLogger.info('SyncService: Sync cancellation requested.');
    }
  }

  // ─── Main entry point ─────────────────────────────────────────────────────

  Future<void> processPendingQueue() async {
    if (_isSyncing) {
      AppLogger.info('SyncService: Already syncing, skipping.');
      return;
    }
    _isSyncing = true;
    _statusCtrl.add(SyncStatus.syncing);

    try {
      lastError = SyncError.none;
      lastErrorMessage = null;
      const provider = 'cactus';
      final localModelId =
          await DatabaseService.instance.getSetting('cactus_model_id') ??
              CactusLocalService.defaultModelId;
      AppLogger.info(
        'SyncService: Starting sync with provider=$provider localModel=$localModelId',
      );

      final aiService = await _buildAIService();

      final queue = await DatabaseService.instance.getPendingQueue();
      AppLogger.info('SyncService: ${queue.length} item(s) in pending queue.');

      if (queue.isEmpty) {
        _statusCtrl.add(SyncStatus.completed);
        return;
      }

      if (provider == 'cactus') {
        final modelPath = await CactusLocalService().getModelPath(localModelId);
        final modelDir = Directory(modelPath);
        if (!await modelDir.exists()) {
          AppLogger.info(
            'SyncService: Local model not found at $modelPath. '
            'Go to Settings to download it.',
          );
          lastError = SyncError.localModelMissing;
          lastErrorMessage =
              'Download the offline AI in Settings before generating explanations.';
          _statusCtrl.add(SyncStatus.error);
          return;
        }
      }

      await _prewarmSelectedModel(provider, localModelId);

      if (!aiService.isConfigured) {
        AppLogger.info('SyncService: AIService is not configured. Aborting.');
        lastError = SyncError.notConfigured;
        lastErrorMessage =
            'Download the offline AI in Settings before generating explanations.';
        _statusCtrl.add(SyncStatus.error);
        return;
      }

      _progressCtrl.add(SyncProgress(processed: 0, total: queue.length));

      int processedCount = 0;
      int totalFailCount = 0;
      int retryPass = 0;

        while (true) {
          if (_isCancelled) {
          AppLogger.info(
            'SyncService: Sync cancelled. Processed $processedCount/${queue.length} before cancellation.',
          );
          break;
        }

        final currentQueue = await DatabaseService.instance.getPendingQueue();
        if (currentQueue.isEmpty) {
          AppLogger.info('SyncService: Queue is empty.');
          break;
        }

        final processable = currentQueue.where((item) {
          final retry = (item['retry_count'] as int?) ?? 0;
          return retry < 3;
        }).toList();

        if (processable.isEmpty) {
          AppLogger.info('SyncService: All remaining items exceed max retries.');
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
            AppLogger.info('SyncService: Exception on word $wordId: $e');
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
        AppLogger.info(
          'SyncService: $passFailCount item(s) failed, retry pass $retryPass. '
          'Waiting ${backoff.inSeconds}s...',
        );
        await Future.delayed(backoff);
      }

      if (_isCancelled) {
        AppLogger.info('SyncService: Sync was cancelled by user.');
        _statusCtrl.add(SyncStatus.idle);
      } else if (totalFailCount > 0 && provider == 'cactus') {
        lastError = SyncError.localModelMissing;
        lastErrorMessage = '$totalFailCount word(s) failed to generate. '
            'The Cactus model may have produced invalid output. '
            'Try repairing the local model in Settings.';
        AppLogger.info('SyncService: $totalFailCount local item(s) failed.');
        await LocalAnalyticsService.instance.track(
          'summary.generation_failed',
          payload: {'failedCount': totalFailCount},
        );
      }

      AppLogger.info(
        'SyncService: Done. $processedCount/${queue.length} processed successfully.',
      );
      _statusCtrl.add(SyncStatus.completed);
    } catch (e) {
      AppLogger.info('SyncService: Fatal error: $e');
      await LocalAnalyticsService.instance.recordError(
        scope: 'sync.process_pending_queue',
        error: e,
      );
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

    AppLogger.info(
      'SyncService: Re-queued $resetCount word(s) without summaries. Starting queue processing...',
    );
    processPendingQueue();
  }

  Future<AIService> _buildAIService() async {
    final localModel =
        await DatabaseService.instance.getSetting('cactus_model_id') ??
            CactusLocalService.defaultModelId;
    AppLogger.info('SyncService: localModel=$localModel');

    final service = AIService();
    service.configure(localModelId: localModel);
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
      AppLogger.info(
        'SyncService: Max retries ($retryCount) for "${word.text}". Marking as not-pending.',
      );
      await DatabaseService.instance.updateWord(
        word.copyWith(isPending: false, updatedAt: DateTime.now()),
      );
      await DatabaseService.instance.removeFromQueue(wordId);
      return true;
    }

    // Exponential back-off on retries
    if (retryCount > 0) {
      final wait = Duration(seconds: pow(2, retryCount).toInt());
      AppLogger.info(
        'SyncService: Retry $retryCount - waiting ${wait.inSeconds}s for "${word.text}".',
      );
      await Future.delayed(wait);
    }

    AppLogger.info('SyncService: Requesting summary for "${word.text}"...');
    final level = UserLevel.fromString(
      await DatabaseService.instance.getSetting('user_level') ??
          UserLevel.beginner.name,
    );
    final summary = await aiService.generateSummary(
      word: word.text,
      context: word.context,
      level: level,
      keepAlive: retryCount < 2,
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
      AppLogger.info('SyncService: Summary saved for "${word.text}".');
      await LocalAnalyticsService.instance.track(
        'summary.generated',
        payload: {'wordId': word.id},
      );
      return true;
    } else {
      await _incrementRetry(wordId);
      AppLogger.info(
        'SyncService: Summary failed for "${word.text}" (retry ${retryCount + 1}).',
      );
      await LocalAnalyticsService.instance.track(
        'summary.generation_failed',
        payload: {
          'wordId': word.id,
          'retryCount': retryCount + 1,
        },
      );
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
        AppLogger.info('SyncService: Cactus prewarm skipped: ${result.message}');
      } else {
        AppLogger.info('SyncService: Cactus model prewarmed: $modelId');
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

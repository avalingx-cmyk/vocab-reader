import 'dart:async';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';

enum SyncStatus { idle, syncing, completed, error }

class SyncProgress {
  final int processed;
  final int total;
  SyncProgress({required this.processed, required this.total});
  double get percentage => total > 0 ? processed / total : 0.0;
}

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final _statusCtrl = StreamController<SyncStatus>.broadcast();
  final _progressCtrl = StreamController<SyncProgress>.broadcast();

  Stream<SyncStatus> get syncStatusStream => _statusCtrl.stream;
  Stream<SyncProgress> get syncProgressStream => _progressCtrl.stream;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // ─── Main entry point ─────────────────────────────────────────────────────

  Future<void> processPendingQueue() async {
    if (_isSyncing) {
      print('SyncService: Already syncing, skipping.');
      return;
    }
    _isSyncing = true;
    _statusCtrl.add(SyncStatus.syncing);

    try {
      // Build AIService with keys from DB, fallback to .env
      final aiService = await _buildAIService();
      
      final queue = await DatabaseService.instance.getPendingQueue();
      print('SyncService: ${queue.length} item(s) in pending queue.');

      if (queue.isEmpty) {
        _statusCtrl.add(SyncStatus.completed);
        return;
      }

      if (!aiService.isConfigured) {
        print('SyncService: No API key configured — aborting sync. '
            'Please set a key in Settings.');
        _statusCtrl.add(SyncStatus.error);
        return;
      }

      _progressCtrl.add(SyncProgress(processed: 0, total: queue.length));

      int processed = 0;
      for (final item in queue) {
        final wordId = item['word_id'] as String;
        try {
          final success = await _processItem(wordId, aiService);
          if (success) processed++;
        } catch (e) {
          print('SyncService: Exception on word $wordId: $e');
          await _incrementRetry(wordId);
        }
        _progressCtrl.add(SyncProgress(processed: processed, total: queue.length));
      }

      print('SyncService: Done. $processed/${queue.length} processed successfully.');
      _statusCtrl.add(SyncStatus.completed);
    } catch (e) {
      print('SyncService: Fatal error: $e');
      _statusCtrl.add(SyncStatus.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Resets all words that have no summary but are not currently pending,
  /// and puts them back into the sync queue.
  Future<void> resetFailedWords() async {
    final words = await DatabaseService.instance.getWords();
    final queue = await DatabaseService.instance.getPendingQueue();
    final queuedIds = queue.map((e) => e['word_id'] as String).toSet();

    int resetCount = 0;
    for (final word in words) {
      // If word has no summary and is not currently in the queue
      if (word.summary == null && !queuedIds.contains(word.id)) {
        await DatabaseService.instance.updateWord(
          word.copyWith(isPending: true, updatedAt: DateTime.now()),
        );
        await DatabaseService.instance.addToQueue(word.id);
        resetCount++;
      }
    }
    
    if (resetCount > 0) {
      print('SyncService: Reset $resetCount failed words. Starting sync...');
      processPendingQueue();
    }
  }

  // ─── Build AIService ──────────────────────────────────────────────────────

  Future<AIService> _buildAIService() async {
    final provider = await DatabaseService.instance.getSetting('ai_provider') ?? 'gemini';
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
        : 'none/short';

    print('SyncService: provider=$provider activeKey=$keyPreview');

    final service = AIService();
    service.configure(openAIKey: openAIKey, geminiKey: geminiKey, provider: provider);
    return service;
  }

  // ─── Process single item ─────────────────────────────────────────────────

  /// Returns true if successfully processed (summary saved or item cleaned up).
  Future<bool> _processItem(String wordId, AIService aiService) async {
    final word = await DatabaseService.instance.getWord(wordId);
    if (word == null) {
      // Orphaned queue entry – remove it
      await DatabaseService.instance.removeFromQueue(wordId);
      return true;
    }

    // Check retry count
    final queueRows = await DatabaseService.instance.getPendingQueue();
    final queueRow = queueRows.firstWhere(
      (r) => r['word_id'] == wordId,
      orElse: () => {'retry_count': 0},
    );
    final retryCount = (queueRow['retry_count'] as int?) ?? 0;

    if (retryCount >= 3) {
      print('SyncService: Max retries ($retryCount) for "$wordId". '
          'Marking as not-pending so it stops blocking.');
      await DatabaseService.instance.updateWord(
        word.copyWith(isPending: false, updatedAt: DateTime.now()),
      );
      await DatabaseService.instance.removeFromQueue(wordId);
      return true;
    }

    // Exponential back-off on retries
    if (retryCount > 0) {
      final wait = Duration(seconds: pow(2, retryCount).toInt());
      print('SyncService: Retry $retryCount – waiting ${wait.inSeconds}s for "$wordId".');
      await Future.delayed(wait);
    }

    final summary = await aiService.generateSummary(
      word: word.text,
      context: word.context,
      level: word.userLevel,
    );

    if (summary != null) {
      await DatabaseService.instance.updateWord(
        word.copyWith(summary: summary, isPending: false, updatedAt: DateTime.now()),
      );
      await DatabaseService.instance.removeFromQueue(wordId);
      print('SyncService: ✓ Summary saved for "${word.text}".');
      return true;
    } else {
      await _incrementRetry(wordId);
      print('SyncService: ✗ Summary failed for "${word.text}" (retry ${retryCount + 1}).');
      return false;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

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
}

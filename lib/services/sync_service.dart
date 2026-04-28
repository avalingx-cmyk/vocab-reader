import 'dart:async';
import 'dart:math';
import '../models/word.dart';
import '../models/user_level.dart';
import 'database_service.dart';
import 'ai_service.dart';

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  final _syncProgressController = StreamController<SyncProgress>.broadcast();

  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;
  Stream<SyncProgress> get syncProgressStream => _syncProgressController.stream;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<void> processPendingQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      _syncStatusController.add(SyncStatus.syncing);

      final queue = await DatabaseService.instance.getPendingQueue();

      if (queue.isEmpty) {
        _syncStatusController.add(SyncStatus.completed);
        _isSyncing = false;
        return;
      }

      _syncProgressController.add(SyncProgress(
        processed: 0,
        total: queue.length,
      ));

      // Load AI configuration
      final provider = await DatabaseService.instance.getSetting('ai_provider') ?? 'openai';
      final openAIKey = await DatabaseService.instance.getSetting('openai_key');
      final geminiKey = await DatabaseService.instance.getSetting('gemini_key');

      final aiService = AIService();
      aiService.configure(
        openAIKey: openAIKey,
        geminiKey: geminiKey,
        provider: provider,
      );

      for (int i = 0; i < queue.length; i++) {
        final queueItem = queue[i];
        final wordId = queueItem['word_id'] as String;

        try {
          await _processQueueItem(wordId, aiService);

          _syncProgressController.add(SyncProgress(
            processed: i + 1,
            total: queue.length,
          ));
        } catch (e) {
          // Update retry count
          await _incrementRetryCount(wordId);
          print('Error processing word $wordId: $e');
        }
      }

      _syncStatusController.add(SyncStatus.completed);
    } catch (e) {
      _syncStatusController.add(SyncStatus.error);
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processQueueItem(String wordId, AIService aiService) async {
    final word = await DatabaseService.instance.getWord(wordId);
    if (word == null) {
      await DatabaseService.instance.removeFromQueue(wordId);
      return;
    }

    // Check retry count
    final queue = await DatabaseService.instance.getPendingQueue();
    final queueItem = queue.firstWhere(
      (item) => item['word_id'] == wordId,
      orElse: () => {},
    );

    final retryCount = queueItem['retry_count'] as int? ?? 0;
    if (retryCount >= 3) {
      // Max retries reached, remove from queue
      await DatabaseService.instance.removeFromQueue(wordId);
      return;
    }

    // Exponential backoff
    if (retryCount > 0) {
      final backoffSeconds = pow(2, retryCount).toInt();
      await Future.delayed(Duration(seconds: backoffSeconds));
    }

    // Generate summary
    final summary = await aiService.generateSummary(
      word: word.text,
      context: word.context,
      level: word.userLevel,
    );

    if (summary != null) {
      // Update word with summary
      final updatedWord = word.copyWith(
        summary: summary,
        isPending: false,
        updatedAt: DateTime.now(),
      );

      await DatabaseService.instance.updateWord(updatedWord);
      await DatabaseService.instance.removeFromQueue(wordId);
    } else {
      // Summary generation failed, increment retry
      await _incrementRetryCount(wordId);
    }
  }

  Future<void> _incrementRetryCount(String wordId) async {
    final db = await DatabaseService.instance.database;
    await db.rawUpdate(
      'UPDATE pending_queue SET retry_count = retry_count + 1 WHERE word_id = ?',
      [wordId],
    );
  }

  Future<void> dispose() async {
    _syncStatusController.close();
    _syncProgressController.close();
  }
}

enum SyncStatus { idle, syncing, completed, error }

class SyncProgress {
  final int processed;
  final int total;

  SyncProgress({
    required this.processed,
    required this.total,
  });

  double get percentage => total > 0 ? processed / total : 0.0;
}

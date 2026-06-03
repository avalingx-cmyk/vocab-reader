import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/quiz_engine.dart';
import '../models/word.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../services/adaptive_quiz_service.dart';
import '../providers/word_provider.dart';
import 'settings_provider.dart';

class QuizState {
  final QuizSession? session;
  final AnswerState lastAnswerState;
  final bool showingAnswer;
  final bool isComplete;
  final bool isGenerating;
  final bool usedAiSession;
  final String? generationNotice;

  const QuizState({
    this.session,
    this.lastAnswerState = AnswerState.unanswered,
    this.showingAnswer = false,
    this.isComplete = false,
    this.isGenerating = false,
    this.usedAiSession = false,
    this.generationNotice,
  });

  QuizState copyWith({
    QuizSession? session,
    AnswerState? lastAnswerState,
    bool? showingAnswer,
    bool? isComplete,
    bool? isGenerating,
    bool? usedAiSession,
    String? generationNotice,
  }) {
    return QuizState(
      session: session ?? this.session,
      lastAnswerState: lastAnswerState ?? this.lastAnswerState,
      showingAnswer: showingAnswer ?? this.showingAnswer,
      isComplete: isComplete ?? this.isComplete,
      isGenerating: isGenerating ?? this.isGenerating,
      usedAiSession: usedAiSession ?? this.usedAiSession,
      generationNotice: generationNotice,
    );
  }
}

class ReviewStats {
  final int dueCount;
  final int newCount;
  final int masteredCount;
  final int weakCount;
  final int reviewedCount;
  final double accuracy;

  const ReviewStats({
    required this.dueCount,
    required this.newCount,
    required this.masteredCount,
    required this.weakCount,
    required this.reviewedCount,
    required this.accuracy,
  });
}

class QuizNotifier extends StateNotifier<QuizState> {
  final List<Word> _allWords;
  final SettingsState _settings;
  final AdaptiveQuizService _adaptiveQuizService;

  QuizNotifier(this._allWords, this._settings, this._adaptiveQuizService)
      : super(const QuizState());

  Future<void> startSession({QuizMode? mode, List<Word>? dueWords}) async {
    final pool = dueWords ?? _allWords;
    final effectiveMode = mode ?? QuizMode.flashcard;
    const sessionSize = 8;

    state = state.copyWith(
      isGenerating: effectiveMode == QuizMode.multipleChoice,
      generationNotice: null,
      lastAnswerState: AnswerState.unanswered,
      showingAnswer: false,
      isComplete: false,
    );

    final result = await _adaptiveQuizService.buildSession(
      allWords: pool,
      mode: effectiveMode,
      sessionSize: sessionSize,
      localModelId: _settings.cactusModelId,
    );

    state = QuizState(
      session: result.session,
      lastAnswerState: AnswerState.unanswered,
      showingAnswer: false,
      isComplete: false,
      isGenerating: false,
      usedAiSession: result.source == QuizSessionSource.ai,
      generationNotice: result.notice,
    );

    await LocalAnalyticsService.instance.track(
      'review.session_started',
      payload: {
        'mode': effectiveMode.name,
        'questionCount': result.session?.totalQuestions ?? 0,
        'source': result.source.name,
      },
    );
  }

  void submitAnswer(String answer) {
    final session = state.session;
    if (session == null || session.isComplete) return;
    final isCorrect = session.submitAnswer(answer);
    state = state.copyWith(
      lastAnswerState: isCorrect ? AnswerState.correct : AnswerState.wrong,
      isComplete: session.isComplete,
    );
    if (session.isComplete) _persistReview(session);
  }

  void submitFlashcard({required bool known}) {
    final session = state.session;
    if (session == null || session.isComplete) return;
    session.submitFlashcard(known: known);
    state = state.copyWith(
      lastAnswerState: known ? AnswerState.correct : AnswerState.wrong,
      showingAnswer: false,
      isComplete: session.isComplete,
    );
    if (session.isComplete) _persistReview(session);
  }

  void flipCard() {
    state = state.copyWith(showingAnswer: !state.showingAnswer);
  }

  void advance() {
    state = state.copyWith(lastAnswerState: AnswerState.unanswered);
  }

  void reset() {
    state = const QuizState();
  }

  Future<void> _persistReview(QuizSession session) async {
    final now = DateTime.now();

    for (final word in session.correctWords) {
      final intervals = [1, 3, 7, 14];
      final reviewIdx = word.successCount.clamp(0, intervals.length - 1);
      final updated = word.copyWith(
        successCount: word.successCount + 1,
        lastReviewedAt: now,
        nextReviewAt: now.add(Duration(days: intervals[reviewIdx])),
      );
      await DatabaseService.instance.updateWord(updated);
    }

    for (final word in session.missedWords) {
      final updated = word.copyWith(
        failureCount: word.failureCount + 1,
        lastReviewedAt: now,
        nextReviewAt: now.add(const Duration(days: 1)),
      );
      await DatabaseService.instance.updateWord(updated);
    }

    await LocalAnalyticsService.instance.track(
      'review.session_completed',
      payload: {
        'mode': session.mode.name,
        'score': session.score,
        'totalQuestions': session.totalQuestions,
        'accuracy': session.accuracy,
      },
    );
  }
}

final quizProvider =
    StateNotifierProvider.autoDispose<QuizNotifier, QuizState>((ref) {
  final wordsAsync = ref.watch(wordListProvider(null));
  final words = wordsAsync.value ?? [];
  final settings = ref.watch(settingsProvider);
  final adaptiveQuizService = ref.watch(adaptiveQuizServiceProvider);
  return QuizNotifier(words, settings, adaptiveQuizService);
});

final adaptiveQuizServiceProvider = Provider<AdaptiveQuizService>((ref) {
  return AdaptiveQuizService();
});

final dueWordsProvider = Provider<List<Word>>((ref) {
  final wordsAsync = ref.watch(wordListProvider(null));
  final words = wordsAsync.value ?? [];
  final now = DateTime.now();
  return words
      .where((w) =>
          w.summary != null &&
          (w.nextReviewAt == null || w.nextReviewAt!.isBefore(now)))
      .toList();
});

final newStudyWordsProvider = Provider<List<Word>>((ref) {
  final wordsAsync = ref.watch(wordListProvider(null));
  final words = wordsAsync.value ?? [];
  return words
      .where((w) =>
          w.summary != null && w.successCount == 0 && w.failureCount == 0)
      .toList();
});

final masteredWordsProvider = Provider<List<Word>>((ref) {
  final wordsAsync = ref.watch(wordListProvider(null));
  final words = wordsAsync.value ?? [];
  return words.where((w) => w.successCount >= 4).toList();
});

final weakWordsProvider = Provider<List<Word>>((ref) {
  final wordsAsync = ref.watch(wordListProvider(null));
  final words = wordsAsync.value ?? [];
  return words
      .where((w) =>
          w.summary != null &&
          w.failureCount > 0 &&
          w.failureCount >= w.successCount)
      .toList();
});

final reviewStatsProvider = Provider<ReviewStats>((ref) {
  final wordsAsync = ref.watch(wordListProvider(null));
  final words = wordsAsync.value ?? [];
  final due = ref.watch(dueWordsProvider);
  final fresh = ref.watch(newStudyWordsProvider);
  final mastered = ref.watch(masteredWordsProvider);
  final weak = ref.watch(weakWordsProvider);

  final reviewedWords = words
      .where((w) => w.lastReviewedAt != null)
      .toList();
  final totalSuccess = words.fold<int>(0, (a, w) => a + w.successCount);
  final totalFailure = words.fold<int>(0, (a, w) => a + w.failureCount);
  final totalAttempts = totalSuccess + totalFailure;
  final accuracy = totalAttempts == 0 ? 0.0 : totalSuccess / totalAttempts;

  return ReviewStats(
    dueCount: due.length,
    newCount: fresh.length,
    masteredCount: mastered.length,
    weakCount: weak.length,
    reviewedCount: reviewedWords.length,
    accuracy: accuracy,
  );
});

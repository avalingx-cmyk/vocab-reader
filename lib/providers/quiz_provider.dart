import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/quiz_engine.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class QuizState {
  final QuizSession? session;
  final AnswerState lastAnswerState;
  final bool showingAnswer; // for flashcard flip reveal
  final bool isComplete;

  const QuizState({
    this.session,
    this.lastAnswerState = AnswerState.unanswered,
    this.showingAnswer = false,
    this.isComplete = false,
  });

  QuizState copyWith({
    QuizSession? session,
    AnswerState? lastAnswerState,
    bool? showingAnswer,
    bool? isComplete,
  }) {
    return QuizState(
      session: session ?? this.session,
      lastAnswerState: lastAnswerState ?? this.lastAnswerState,
      showingAnswer: showingAnswer ?? this.showingAnswer,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class QuizNotifier extends StateNotifier<QuizState> {
  final List<Word> _allWords;

  QuizNotifier(this._allWords) : super(const QuizState());

  void startSession(QuizMode mode) {
    final session = QuizEngine.buildSession(
      allWords: _allWords,
      mode: mode,
      sessionSize: mode == QuizMode.speedRound ? 10 : 8,
    );
    state = QuizState(
      session: session,
      lastAnswerState: AnswerState.unanswered,
      showingAnswer: false,
      isComplete: false,
    );
  }

  /// Submit MCQ / Speed Round / Spelling Bee answer
  void submitAnswer(String answer) {
    final session = state.session;
    if (session == null || session.isComplete) return;
    final isCorrect = session.submitAnswer(answer);
    state = state.copyWith(
      lastAnswerState: isCorrect ? AnswerState.correct : AnswerState.wrong,
      isComplete: session.isComplete,
    );
  }

  /// Flashcard: known / unknown
  void submitFlashcard({required bool known}) {
    final session = state.session;
    if (session == null || session.isComplete) return;
    session.submitFlashcard(known: known);
    state = state.copyWith(
      lastAnswerState: known ? AnswerState.correct : AnswerState.wrong,
      showingAnswer: false,
      isComplete: session.isComplete,
    );
  }

  void flipCard() {
    state = state.copyWith(showingAnswer: !state.showingAnswer);
  }

  /// Advance past the answer-reveal delay
  void advance() {
    state = state.copyWith(lastAnswerState: AnswerState.unanswered);
  }

  void reset() {
    state = const QuizState();
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final quizProvider =
    StateNotifierProvider.autoDispose<QuizNotifier, QuizState>((ref) {
  // Watch all words that have AI summaries
  final wordsAsync = ref.watch(wordListProvider(null));
  final words = wordsAsync.value ?? [];
  return QuizNotifier(words);
});

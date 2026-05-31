import 'dart:math';
import '../models/word.dart';

enum QuizMode {
  flashcard,
  multipleChoice,
  spellingBee,
  speedRound,
}

enum AnswerState { unanswered, correct, wrong }

class QuizQuestion {
  final Word word;
  final QuizMode mode;
  final List<String> options; // for MCQ / speed round
  final String correctAnswer;
  final String questionLabel;
  final String questionText;
  final String? explanation;
  final String? difficultyTag;
  final bool isAiGenerated;

  const QuizQuestion({
    required this.word,
    required this.mode,
    required this.options,
    required this.correctAnswer,
    this.questionLabel = '',
    this.questionText = '',
    this.explanation,
    this.difficultyTag,
    this.isAiGenerated = false,
  });
}

class QuizSession {
  final List<QuizQuestion> questions;
  final QuizMode mode;

  int currentIndex = 0;
  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  final List<Word> missedWords = [];
  final List<Word> correctWords = [];
  final List<AnswerState> answerStates;

  QuizSession({required this.questions, required this.mode})
      : answerStates = List.filled(questions.length, AnswerState.unanswered);

  bool get isComplete => currentIndex >= questions.length;
  QuizQuestion? get currentQuestion =>
      isComplete ? null : questions[currentIndex];
  int get totalQuestions => questions.length;
  double get accuracy =>
      totalQuestions == 0 ? 0 : score / totalQuestions;
  int get xpEarned => score * 10 + bestStreak * 5;

  /// Returns true if the answer is correct, advances session state.
  bool submitAnswer(String answer) {
    if (isComplete) return false;
    final q = questions[currentIndex];
    final isCorrect =
        answer.toLowerCase().trim() == q.correctAnswer.toLowerCase().trim();

    answerStates[currentIndex] =
        isCorrect ? AnswerState.correct : AnswerState.wrong;

    if (isCorrect) {
      score++;
      streak++;
      correctWords.add(q.word);
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
      missedWords.add(q.word);
    }
    currentIndex++;
    return isCorrect;
  }

  /// Flashcard-only: mark known/unknown without a typed answer.
  void submitFlashcard({required bool known}) {
    if (isComplete) return;
    final q = questions[currentIndex];
    answerStates[currentIndex] =
        known ? AnswerState.correct : AnswerState.wrong;
    if (known) {
      score++;
      streak++;
      correctWords.add(q.word);
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
      missedWords.add(q.word);
    }
    currentIndex++;
  }
}

class QuizEngine {
  static final _rng = Random();

  /// Build a quiz session from available words.
  /// [sessionSize] how many questions per round.
  static QuizSession? buildSession({
    required List<Word> allWords,
    required QuizMode mode,
    int sessionSize = 10,
  }) {
    final eligible = allWords.where((w) => w.summary != null).toList();
    if (eligible.isEmpty) return null;

    // Shuffle so each session feels fresh
    eligible.shuffle(_rng);
    final pool =
        eligible.take(min(sessionSize, eligible.length)).toList();

    final questions = pool.map((word) {
      return _buildQuestion(word: word, mode: mode, allWords: eligible);
    }).toList();

    return QuizSession(questions: questions, mode: mode);
  }

  static QuizQuestion _buildQuestion({
    required Word word,
    required QuizMode mode,
    required List<Word> allWords,
  }) {
    final definition = word.summary!.definition;

    switch (mode) {
      case QuizMode.flashcard:
        return QuizQuestion(
          word: word,
          mode: mode,
          options: const [],
          correctAnswer: definition,
          questionText: word.text,
        );

      case QuizMode.multipleChoice:
      case QuizMode.speedRound:
        final distractors = _pickDistractors(
          correct: definition,
          allWords: allWords,
          exclude: word,
          count: 3,
        );
        final options = [definition, ...distractors]..shuffle(_rng);
        return QuizQuestion(
          word: word,
          mode: mode,
          options: options,
          correctAnswer: definition,
          questionLabel: 'What does this word mean?',
          questionText: word.text,
        );

      case QuizMode.spellingBee:
        return QuizQuestion(
          word: word,
          mode: mode,
          options: const [],
          correctAnswer: word.text,
          questionText: word.summary!.definition,
        );
    }
  }

  static List<String> _pickDistractors({
    required String correct,
    required List<Word> allWords,
    required Word exclude,
    required int count,
  }) {
    final candidates = allWords
        .where((w) =>
            w.id != exclude.id &&
            w.summary != null &&
            w.summary!.definition != correct)
        .toList()
      ..shuffle(_rng);

    return candidates
        .take(count)
        .map((w) => w.summary!.definition)
        .toList();
  }
}

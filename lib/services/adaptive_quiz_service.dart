import '../game/quiz_engine.dart';
import '../models/word.dart';
import 'ai_service.dart';

enum QuizSessionSource {
  standard,
  ai,
  fallback,
}

class AdaptiveQuizSessionResult {
  final QuizSession? session;
  final QuizSessionSource source;
  final String? notice;

  const AdaptiveQuizSessionResult({
    required this.session,
    required this.source,
    this.notice,
  });
}

class AdaptiveQuizService {
  final QuizAiGateway _aiGateway;

  AdaptiveQuizService({QuizAiGateway? aiGateway})
      : _aiGateway = aiGateway ?? AIService();

  Future<AdaptiveQuizSessionResult> buildSession({
    required List<Word> allWords,
    required QuizMode mode,
    required int sessionSize,
    required String provider,
    required String localModelId,
    String? openAIKey,
    String? geminiKey,
  }) async {
    final standardSession = QuizEngine.buildSession(
      allWords: allWords,
      mode: mode,
      sessionSize: sessionSize,
    );

    if (mode != QuizMode.multipleChoice && mode != QuizMode.speedRound) {
      return AdaptiveQuizSessionResult(
        session: standardSession,
        source: QuizSessionSource.standard,
      );
    }

    final eligible = allWords.where((word) => word.summary != null).toList();
    if (eligible.isEmpty) {
      return const AdaptiveQuizSessionResult(
        session: null,
        source: QuizSessionSource.standard,
      );
    }

    final quizWords = eligible.take(sessionSize).toList();

    _aiGateway.configure(
      openAIKey: openAIKey,
      geminiKey: geminiKey,
      provider: provider,
      localModelId: localModelId,
    );

    final generated = await _aiGateway.generateQuizSession(
      words: quizWords,
      mode: mode,
      sessionSize: quizWords.length,
    );

    if (generated.isSuccess) {
      final aiSession = _buildAiSession(
        questions: generated.questions,
        words: quizWords,
        mode: mode,
      );
      if (aiSession != null) {
        return AdaptiveQuizSessionResult(
          session: aiSession,
          source: QuizSessionSource.ai,
        );
      }
    }

    return AdaptiveQuizSessionResult(
      session: standardSession,
      source: QuizSessionSource.fallback,
      notice: 'Using standard quiz for this round.',
    );
  }

  QuizSession? _buildAiSession({
    required List<AiQuizQuestionData> questions,
    required List<Word> words,
    required QuizMode mode,
  }) {
    final wordsById = {for (final word in words) word.id: word};
    final quizQuestions = <QuizQuestion>[];

    for (final question in questions) {
      final word = wordsById[question.wordId];
      if (word == null) continue;

      quizQuestions.add(
        QuizQuestion(
          word: word,
          mode: mode,
          options: [question.correctAnswer, ...question.distractors],
          correctAnswer: question.correctAnswer,
          questionLabel: 'Choose the best answer',
          questionText: question.prompt,
          explanation: question.explanation,
          difficultyTag: question.difficultyTag,
          isAiGenerated: true,
        ),
      );
    }

    if (quizQuestions.isEmpty) return null;
    return QuizSession(questions: quizQuestions, mode: mode);
  }
}

import '../game/quiz_engine.dart';
import '../models/user_level.dart';
import '../models/word.dart';

class AiSummaryResult {
  final WordSummary? summary;
  final WordSummary? partialSummary;
  final String? failureStage;
  final String? errorMessage;
  final int loadMs;
  final int generateMs;

  const AiSummaryResult({
    this.summary,
    this.partialSummary,
    this.failureStage,
    this.errorMessage,
    this.loadMs = 0,
    this.generateMs = 0,
  });

  bool get isSuccess => summary != null;
}

class AiQuizQuestionData {
  final String wordId;
  final String prompt;
  final String correctAnswer;
  final List<String> distractors;
  final String? explanation;
  final String difficultyTag;

  const AiQuizQuestionData({
    required this.wordId,
    required this.prompt,
    required this.correctAnswer,
    required this.distractors,
    this.explanation,
    required this.difficultyTag,
  });
}

class AiQuizGenerationResult {
  final List<AiQuizQuestionData> questions;
  final String? failureStage;
  final String? errorMessage;

  const AiQuizGenerationResult({
    this.questions = const [],
    this.failureStage,
    this.errorMessage,
  });

  bool get isSuccess => questions.isNotEmpty;
}

abstract class SummaryAiGateway {
  void configure({required String localModelId});

  bool get isConfigured;

  Future<AiSummaryResult> generateSummaryDetailed({
    required String word,
    required String? context,
    required UserLevel level,
    bool keepAlive = false,
  });
}

abstract class QuizAiGateway {
  void configure({required String localModelId});

  Future<AiQuizGenerationResult> generateQuizSession({
    required List<Word> words,
    required QuizMode mode,
    required int sessionSize,
  });
}

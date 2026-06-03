import '../game/quiz_engine.dart';
import '../models/user_level.dart';
import '../models/word.dart';
import 'ai_gateway.dart';
import 'ai_summary_parser.dart';
import 'cactus_ai_gateway.dart';
import 'package:flutter/foundation.dart';

export 'ai_gateway.dart';

class AIService implements SummaryAiGateway, QuizAiGateway {
  AIService({
    SummaryAiGateway? summaryGateway,
    QuizAiGateway? quizGateway,
    AiSummaryParser? parser,
  })  : _parser = parser ?? const AiSummaryParser(),
        _summaryGateway =
            summaryGateway ?? CactusAiGateway(parser: parser ?? const AiSummaryParser()),
        _quizGateway =
            quizGateway ?? CactusAiGateway(parser: parser ?? const AiSummaryParser());

  final AiSummaryParser _parser;
  final SummaryAiGateway _summaryGateway;
  final QuizAiGateway _quizGateway;

  @override
  void configure({required String localModelId}) {
    _summaryGateway.configure(localModelId: localModelId);
    _quizGateway.configure(localModelId: localModelId);
  }

  @override
  bool get isConfigured => _summaryGateway.isConfigured;

  Future<WordSummary?> generateSummary({
    required String word,
    required String? context,
    required UserLevel level,
    bool keepAlive = false,
  }) async {
    final result = await generateSummaryDetailed(
      word: word,
      context: context,
      level: level,
      keepAlive: keepAlive,
    );
    return result.summary;
  }

  @override
  Future<AiSummaryResult> generateSummaryDetailed({
    required String word,
    required String? context,
    required UserLevel level,
    bool keepAlive = false,
  }) {
    return _summaryGateway.generateSummaryDetailed(
      word: word,
      context: context,
      level: level,
      keepAlive: keepAlive,
    );
  }

  @override
  Future<AiQuizGenerationResult> generateQuizSession({
    required List<Word> words,
    required QuizMode mode,
    required int sessionSize,
  }) {
    return _quizGateway.generateQuizSession(
      words: words,
      mode: mode,
      sessionSize: sessionSize,
    );
  }

  @visibleForTesting
  String debugBuildQuizUserPromptForTesting({
    required List<Word> words,
    required QuizMode mode,
    required int sessionSize,
  }) {
    return _parser.buildQuizUserPrompt(words: words, sessionSize: sessionSize);
  }

  @visibleForTesting
  AiQuizGenerationResult? debugParseQuizGenerationForTesting(String raw) {
    return _parser.parseQuizGeneration(raw);
  }

  @visibleForTesting
  List<AiQuizQuestionData> debugValidateQuizQuestionsForTesting({
    required List<AiQuizQuestionData> questions,
    required List<Word> words,
    required int expectedCount,
  }) {
    return _parser.validateQuizQuestions(
      questions,
      words: words,
      expectedCount: expectedCount,
    );
  }
}

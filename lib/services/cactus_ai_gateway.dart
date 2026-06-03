import '../game/quiz_engine.dart';
import '../models/user_level.dart';
import '../models/word.dart';
import 'ai_gateway.dart';
import 'ai_summary_parser.dart';
import 'app_logger.dart';
import 'cactus_local_service.dart';

class CactusAiGateway implements SummaryAiGateway, QuizAiGateway {
  CactusAiGateway({
    CactusLocalService? cactusService,
    AiSummaryParser? parser,
  })  : _cactusService = cactusService ?? CactusLocalService(),
        _parser = parser ?? const AiSummaryParser();

  final CactusLocalService _cactusService;
  final AiSummaryParser _parser;
  String? _localModelId;

  @override
  void configure({required String localModelId}) {
    _localModelId = localModelId.trim().isEmpty ? null : localModelId.trim();
  }

  @override
  bool get isConfigured => _localModelId != null;

  @override
  Future<AiSummaryResult> generateSummaryDetailed({
    required String word,
    required String? context,
    required UserLevel level,
    bool keepAlive = false,
  }) async {
    final modelId = _localModelId;
    if (modelId == null) {
      return const AiSummaryResult(
        failureStage: 'model-not-selected',
        errorMessage: 'Local model not selected.',
      );
    }

    final initWatch = Stopwatch()..start();
    final initResult = await _cactusService.initialize(modelId);
    initWatch.stop();
    if (!initResult.isSuccess) {
      return AiSummaryResult(
        failureStage: 'load-failed',
        errorMessage: initResult.message ?? 'Local model failed to load.',
        loadMs: initWatch.elapsedMilliseconds,
      );
    }

    AppLogger.info('CactusAiGateway: generating summary for "$word"');
    final genResult = await _cactusService.generateText(
      _parser.buildSummaryUserPrompt(
        word: word,
        context: context,
        learnerLevel: level.displayName,
      ),
      systemPrompt: _parser.buildSummarySystemPrompt(),
      maxTokens: 400,
      temperature: 0.0,
    );

    if (!genResult.isSuccess || genResult.text == null) {
      return AiSummaryResult(
        failureStage: genResult.error == CactusAiError.generationTimeout
            ? 'timed-out'
            : 'generation-failed',
        errorMessage: genResult.message ?? 'Local generation failed.',
        loadMs: initWatch.elapsedMilliseconds,
        generateMs: genResult.totalTimeMs.round(),
      );
    }

    final summary = _parser.parseSummary(genResult.text!, word: word);
    if (summary == null) {
      return AiSummaryResult(
        failureStage: 'parse-failed',
        errorMessage: 'Local model returned invalid JSON.',
        loadMs: initWatch.elapsedMilliseconds,
        generateMs: genResult.totalTimeMs.round(),
      );
    }

    return AiSummaryResult(
      summary: summary,
      loadMs: initWatch.elapsedMilliseconds,
      generateMs: genResult.totalTimeMs.round(),
    );
  }

  @override
  Future<AiQuizGenerationResult> generateQuizSession({
    required List<Word> words,
    required QuizMode mode,
    required int sessionSize,
  }) async {
    final modelId = _localModelId;
    if (modelId == null) {
      return const AiQuizGenerationResult(
        failureStage: 'model-not-selected',
        errorMessage: 'Local model not selected.',
      );
    }

    final initResult = await _cactusService.initialize(modelId);
    if (!initResult.isSuccess) {
      return AiQuizGenerationResult(
        failureStage: 'load-failed',
        errorMessage: initResult.message ?? 'Local model failed to load.',
      );
    }

    final genResult = await _cactusService.generateText(
      _parser.buildQuizUserPrompt(words: words, sessionSize: sessionSize),
      systemPrompt: _parser.buildQuizSystemPrompt(),
      maxTokens: 700,
      temperature: 0.0,
    );
    if (!genResult.isSuccess || genResult.text == null) {
      return AiQuizGenerationResult(
        failureStage: 'generation-failed',
        errorMessage: genResult.message ?? 'Local quiz generation failed.',
      );
    }

    final parsed = _parser.parseQuizGeneration(genResult.text);
    final cleaned = _parser.validateQuizQuestions(
      parsed?.questions ?? const [],
      words: words,
      expectedCount: sessionSize,
    );
    if (cleaned.isEmpty) {
      return const AiQuizGenerationResult(
        failureStage: 'validation-failed',
        errorMessage: 'Local quiz output did not pass validation.',
      );
    }
    return AiQuizGenerationResult(questions: cleaned);
  }
}

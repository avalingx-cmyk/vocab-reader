import 'package:bookbeam/game/quiz_engine.dart';
import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/models/word.dart';
import 'package:bookbeam/services/adaptive_quiz_service.dart';
import 'package:bookbeam/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveQuizService', () {
    final words = [
      _word(
        id: 'w1',
        text: 'ephemeral',
        definition: 'Lasting for only a short time.',
      ),
      _word(
        id: 'w2',
        text: 'meticulous',
        definition: 'Very careful and precise.',
      ),
      _word(
        id: 'w3',
        text: 'resilient',
        definition: 'Able to recover quickly.',
      ),
      _word(
        id: 'w4',
        text: 'ambiguous',
        definition: 'Open to more than one meaning.',
      ),
    ];

    test('uses AI-generated session when generation succeeds', () async {
      final gateway = _FakeQuizAiGateway(
        result: AiQuizGenerationResult(
          questions: const [
            AiQuizQuestionData(
              wordId: 'w1',
              prompt: 'Choose the best meaning of ephemeral.',
              correctAnswer: 'Lasting for only a short time.',
              distractors: [
                'Very careful and precise.',
                'Able to recover quickly.',
                'Open to more than one meaning.',
              ],
              explanation: 'Ephemeral means brief or short-lived.',
              difficultyTag: 'easy',
            ),
          ],
        ),
      );
      final service = AdaptiveQuizService(aiGateway: gateway);

      final result = await service.buildSession(
        allWords: words,
        mode: QuizMode.multipleChoice,
        sessionSize: 1,
        provider: 'cactus',
        localModelId: 'qwen3-0.6b',
      );

      expect(result.source, QuizSessionSource.ai);
      expect(result.session, isNotNull);
      expect(result.session!.questions.single.explanation,
          'Ephemeral means brief or short-lived.');
      expect(gateway.lastConfiguredProvider, 'cactus');
      expect(gateway.lastConfiguredLocalModelId, 'qwen3-0.6b');
    });

    test('falls back to standard quiz when AI generation fails', () async {
      final service = AdaptiveQuizService(
        aiGateway: _FakeQuizAiGateway(
          result: const AiQuizGenerationResult(
            failureStage: 'generation-failed',
            errorMessage: 'Cloud generation failed.',
          ),
        ),
      );

      final result = await service.buildSession(
        allWords: words,
        mode: QuizMode.multipleChoice,
        sessionSize: 3,
        provider: 'gemini',
        geminiKey: 'g-key',
        localModelId: 'qwen3-0.6b',
      );

      expect(result.source, QuizSessionSource.fallback);
      expect(result.session, isNotNull);
      expect(result.notice, contains('Using standard quiz'));
      expect(result.session!.questions, hasLength(3));
    });
  });
}

class _FakeQuizAiGateway implements QuizAiGateway {
  _FakeQuizAiGateway({required this.result});

  final AiQuizGenerationResult result;
  String? lastConfiguredProvider;
  String? lastConfiguredLocalModelId;

  @override
  void configure({
    String? openAIKey,
    String? geminiKey,
    String provider = 'gemini',
    String? localModelId,
  }) {
    lastConfiguredProvider = provider;
    lastConfiguredLocalModelId = localModelId;
  }

  @override
  Future<AiQuizGenerationResult> generateQuizSession({
    required List<Word> words,
    required QuizMode mode,
    required int sessionSize,
  }) async {
    return result;
  }
}

Word _word({
  required String id,
  required String text,
  required String definition,
}) {
  return Word(
    id: id,
    text: text,
    bookName: 'Book',
    userLevel: UserLevel.beginner,
    summary: WordSummary(
      definition: definition,
      mainSay: definition,
      useCases: ['Example for $text.'],
      similarWords: const ['related', 'similar', 'close'],
      detailedSummary: definition,
      generatedAt: DateTime(2025, 1, 1),
    ),
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );
}

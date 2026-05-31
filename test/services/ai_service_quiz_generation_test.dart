import 'package:bookbeam/game/quiz_engine.dart';
import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/models/word.dart';
import 'package:bookbeam/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI quiz generation helpers', () {
    final service = AIService();
    final words = [
      _buildWord(
        id: 'w1',
        text: 'ephemeral',
        definition: 'Lasting for only a short time.',
        useCases: ['The beauty of the sunset was ephemeral.'],
        successCount: 0,
        failureCount: 2,
        context: 'The celebration felt ephemeral after the crowd dispersed.',
      ),
      _buildWord(
        id: 'w2',
        text: 'meticulous',
        definition: 'Very careful and precise.',
        useCases: ['She was meticulous when organizing her research notes.'],
        successCount: 4,
        failureCount: 0,
      ),
    ];

    test('builds a compact quiz prompt with progress context', () {
      final prompt = service.debugBuildQuizUserPromptForTesting(
        words: words,
        mode: QuizMode.multipleChoice,
        sessionSize: 2,
      );

      expect(prompt, contains('ephemeral'));
      expect(prompt, contains('successCount: 0'));
      expect(prompt, contains('failureCount: 2'));
      expect(prompt, contains('The celebration felt ephemeral'));
      expect(prompt, contains('meticulous'));
      expect(prompt, contains('Return ONLY valid JSON'));
    });

    test('parses valid quiz JSON', () {
      const raw = '''
{
  "questions": [
    {
      "wordId": "w1",
      "prompt": "Choose the best meaning of ephemeral.",
      "correctAnswer": "Lasting for only a short time.",
      "distractors": [
        "Carefully organized and exact.",
        "Strong enough to recover quickly.",
        "Open to more than one meaning."
      ],
      "explanation": "Ephemeral describes something brief or short-lived.",
      "difficultyTag": "easy"
    },
    {
      "wordId": "w2",
      "prompt": "Which option best matches meticulous?",
      "correctAnswer": "Very careful and precise.",
      "distractors": [
        "Short-lived and temporary.",
        "Not willing to change.",
        "Unclear or confusing."
      ],
      "difficultyTag": "hard"
    }
  ]
}
''';

      final result = service.debugParseQuizGenerationForTesting(raw);

      expect(result, isNotNull);
      expect(result!.questions, hasLength(2));
      expect(result.questions.first.explanation, isNotEmpty);
      expect(result.questions.last.explanation, isNull);
    });

    test('rejects duplicate options during validation', () {
      final validated = service.debugValidateQuizQuestionsForTesting(
        questions: [
          const AiQuizQuestionData(
            wordId: 'w1',
            prompt: 'Choose the best meaning of ephemeral.',
            correctAnswer: 'Lasting for only a short time.',
            distractors: [
              'Lasting for only a short time.',
              'Carefully organized and exact.',
              'Strong enough to recover quickly.',
            ],
            explanation: 'Ephemeral means short-lived.',
            difficultyTag: 'easy',
          ),
        ],
        words: [words.first],
        expectedCount: 1,
      );

      expect(validated, isEmpty);
    });

    test('rejects malformed quiz JSON', () {
      final result = service.debugParseQuizGenerationForTesting(
        '{"questions":[{"wordId":"w1","prompt":"oops"}]}',
      );

      expect(result, isNull);
    });
  });
}

Word _buildWord({
  required String id,
  required String text,
  required String definition,
  required List<String> useCases,
  int successCount = 0,
  int failureCount = 0,
  String? context,
}) {
  return Word(
    id: id,
    text: text,
    bookName: 'Book',
    context: context,
    userLevel: UserLevel.beginner,
    summary: WordSummary(
      definition: definition,
      mainSay: definition,
      useCases: useCases,
      similarWords: const ['brief', 'fleeting', 'temporary'],
      detailedSummary: definition,
      generatedAt: DateTime(2025, 1, 1),
    ),
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    successCount: successCount,
    failureCount: failureCount,
  );
}

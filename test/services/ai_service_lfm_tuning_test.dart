import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/models/word.dart';
import 'package:bookbeam/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LFM 350M tuning', () {
    test('keeps a fuller dictionary-style definition after cleanup', () {
      final service = AIService();
      final summary = WordSummary(
        definition:
            'Something that lasts for only a short time and then fades or disappears quickly.',
        mainSay: '',
        useCases: const [
          'The exhibition captured the ephemeral mood of the city at dawn.',
          'Her relief was ephemeral after the second report arrived.',
          'The market celebrated an ephemeral surge before confidence fell again.',
        ],
        similarWords: const ['fleeting', 'transitory', 'short-lived'],
        detailedSummary: '',
        generatedAt: DateTime(2026, 1, 1),
      );

      final cleaned = service.debugCleanSummaryForTesting(
        word: 'ephemeral',
        summary: summary,
        modelId: 'lfm-350m',
      );

      expect(cleaned, isNotNull);
      expect(
        cleaned!.definition,
        'Something that lasts for only a short time and then fades or disappears quickly.',
      );
    });

    test('asks lfm-350m for a richer dictionary-style definition', () {
      final service = AIService();

      final systemPrompt =
          service.debugBuildCactusSystemPromptForTesting('lfm-350m');
      final userPrompt = service.debugBuildCactusUserPromptForTesting(
        word: 'ephemeral',
        context: 'The celebration felt ephemeral after the crowd dispersed.',
        level: UserLevel.beginner,
        modelId: 'lfm-350m',
      );

      expect(systemPrompt.toLowerCase(),
          isNot(contains('definition must be short')));
      expect(userPrompt.toLowerCase(), isNot(contains('short direct meaning')));
      expect(userPrompt.toLowerCase(), contains('dictionary-style'));
    });

    test('splits packed similar words so lfm summaries are not rejected', () {
      final service = AIService();
      final summary = WordSummary(
        definition:
            'Something that lasts for only a short time before disappearing.',
        mainSay: '',
        useCases: const [
          'The celebration felt ephemeral after the guests went home.',
          'Their excitement was ephemeral once the final numbers appeared.',
        ],
        similarWords: const ['fleeting, transient, short-lived'],
        detailedSummary: '',
        generatedAt: DateTime(2026, 1, 1),
      );

      final cleaned = service.debugCleanSummaryForTesting(
        word: 'ephemeral',
        summary: summary,
        modelId: 'lfm-350m',
      );

      expect(cleaned, isNotNull);
      expect(cleaned!.similarWords, containsAll(['fleeting', 'transient']));
      expect(cleaned.similarWords.length, greaterThanOrEqualTo(3));
    });

    test('builds a partial benchmark preview for weak but parseable output', () {
      final service = AIService();
      final summary = WordSummary(
        definition: 'Lasting a short time.',
        mainSay: '',
        useCases: const ['ephemeral moments'],
        similarWords: const ['transient, brief'],
        detailedSummary: '',
        generatedAt: DateTime(2026, 1, 1),
      );

      final preview = service.debugBuildBenchmarkPreviewForTesting(
        word: 'ephemeral',
        summary: summary,
        modelId: 'lfm-1.2b',
      );

      expect(preview, isNotNull);
      expect(preview!.definition, isNotEmpty);
      expect(preview.useCases, contains('ephemeral moments'));
      expect(preview.similarWords, containsAll(['transient', 'brief']));
    });
  });
}

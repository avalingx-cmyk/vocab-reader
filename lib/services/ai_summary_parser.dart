import 'dart:convert';

import '../models/word.dart';
import 'ai_gateway.dart';

class AiSummaryParser {
  const AiSummaryParser();

  WordSummary? parseSummary(String content, {required String word}) {
    try {
      var clean = _stripCodeFences(content).trim();
      if (clean.isEmpty) {
        return null;
      }

      final extractedJson = _extractJsonObject(clean);
      if (extractedJson == null) {
        return null;
      }

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(extractedJson) as Map<String, dynamic>;
      } catch (_) {
        data = jsonDecode(_fixCommonJsonIssues(extractedJson))
            as Map<String, dynamic>;
      }

      final definition = _normalizeSentence(
        (data['definition'] as String?) ?? '',
        fallback: 'Meaning unavailable.',
      );
      final useCases = _normalizeList(data['useCases'], minItems: 2);
      final similarWords = _normalizeList(data['similarWords'], minItems: 2);

      if (definition.isEmpty || useCases.isEmpty || similarWords.isEmpty) {
        return null;
      }

      final detailedSummary =
          _normalizeSentence((data['detailedSummary'] as String?) ?? definition);
      final mainSay =
          _normalizeSentence((data['mainSay'] as String?) ?? definition);

      return WordSummary(
        definition: definition,
        mainSay: mainSay,
        useCases: useCases,
        similarWords: _removeDuplicates(similarWords, exclude: word),
        detailedSummary: detailedSummary,
        generatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  String buildSummarySystemPrompt() {
    return 'You are a dictionary-style vocabulary assistant. Output ONLY valid '
        'JSON with exactly these keys: {"definition":"","useCases":["","",""],'
        '"similarWords":["","",""]}. '
        'Definition must be clear and plain English. '
        'Use cases must be natural complete sentences. '
        'Similar words must be precise, unique, and useful. '
        'Do not add any text before or after JSON.';
  }

  String buildSummaryUserPrompt({
    required String word,
    required String? context,
    required String learnerLevel,
  }) {
    final ctx = context == null || context.trim().isEmpty
        ? ''
        : ' Context: "${context.trim()}".';
    return '''
Create a vocabulary card for "$word" at $learnerLevel level.$ctx

Return ONLY valid JSON:
- definition: one clear plain-English meaning
- useCases: three short natural sentences using "$word"
- similarWords: three precise similar words

Rules:
- Keep the definition concise and easy to understand.
- Use exactly 3 use cases and 3 similar words.
- Each use case must be a full sentence.
- Similar words must be unique and must not repeat "$word".
- Do not include markdown or explanation outside JSON.
''';
  }

  String buildQuizSystemPrompt() {
    return 'You are a vocabulary quiz generator. Output ONLY valid JSON in '
        'this shape: {"questions":[{"wordId":"","prompt":"","correctAnswer":"",'
        '"distractors":["","",""],"explanation":"","difficultyTag":""}]}. '
        'Create concise multiple-choice questions with one correct answer and '
        'three unique distractors. Do not add markdown or extra commentary.';
  }

  String buildQuizUserPrompt({
    required List<Word> words,
    required int sessionSize,
  }) {
    final buffer = StringBuffer()
      ..writeln('Create $sessionSize multiple-choice vocabulary questions.')
      ..writeln('Return ONLY valid JSON with a top-level "questions" array.')
      ..writeln('Each question must include: wordId, prompt, correctAnswer, '
          'distractors, explanation, difficultyTag.')
      ..writeln('Rules:')
      ..writeln('- Keep prompts short and easy to read on mobile.')
      ..writeln('- Use exactly 3 distractors per question.')
      ..writeln('- Make weak/new words easier and mastered words trickier.')
      ..writeln('- Prefer context-aware distractors when book context exists.')
      ..writeln('- Keep explanations under 18 words.')
      ..writeln('- Do not repeat the correct answer in distractors.')
      ..writeln('')
      ..writeln('Words:');

    for (final word in words.take(sessionSize)) {
      final difficulty = word.failureCount > word.successCount
          ? 'easy'
          : word.successCount >= 3
              ? 'hard'
              : 'medium';
      buffer.writeln(
        '- wordId: ${word.id}; text: ${word.text}; definition: '
        '${word.summary?.definition ?? ''}; useCase: '
        '${word.summary != null && word.summary!.useCases.isNotEmpty ? word.summary!.useCases.first : word.context ?? ''}; '
        'successCount: ${word.successCount}; failureCount: ${word.failureCount}; '
        'difficultyTarget: $difficulty; context: ${word.context ?? ''}',
      );
    }

    return buffer.toString();
  }

  AiQuizGenerationResult? parseQuizGeneration(String? content) {
    if (content == null || content.trim().isEmpty) {
      return null;
    }

    try {
      final clean = _extractJsonObject(_stripCodeFences(content).trim());
      if (clean == null) {
        return null;
      }

      final data = jsonDecode(_fixCommonJsonIssues(clean)) as Map<String, dynamic>;
      final rawQuestions = data['questions'];
      if (rawQuestions is! List) {
        return null;
      }

      final questions = <AiQuizQuestionData>[];
      for (final item in rawQuestions) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final wordId = (item['wordId'] as String? ?? '').trim();
        final prompt = (item['prompt'] as String? ?? '').trim();
        final correctAnswer = (item['correctAnswer'] as String? ?? '').trim();
        final distractors = _normalizeList(item['distractors'], minItems: 3);

        if (wordId.isEmpty ||
            prompt.isEmpty ||
            correctAnswer.isEmpty ||
            distractors.length != 3) {
          continue;
        }

        questions.add(
          AiQuizQuestionData(
            wordId: wordId,
            prompt: prompt,
            correctAnswer: correctAnswer,
            distractors: distractors,
            explanation: _optionalSentence(item['explanation'] as String?),
            difficultyTag:
                _optionalSentence(item['difficultyTag'] as String?) ?? 'medium',
          ),
        );
      }

      if (questions.isEmpty) {
        return null;
      }

      return AiQuizGenerationResult(questions: questions);
    } catch (_) {
      return null;
    }
  }

  List<AiQuizQuestionData> validateQuizQuestions(
    List<AiQuizQuestionData> questions, {
    required List<Word> words,
    required int expectedCount,
  }) {
    final wordsById = {for (final word in words) word.id: word};
    final cleaned = <AiQuizQuestionData>[];

    for (final question in questions) {
      if (!wordsById.containsKey(question.wordId)) {
        continue;
      }

      final options = [
        question.correctAnswer.trim(),
        ...question.distractors.map((item) => item.trim()),
      ];
      final normalized = options.map((item) => item.toLowerCase()).toList();
      if (normalized.any((item) => item.isEmpty) ||
          normalized.toSet().length != 4) {
        continue;
      }

      final explanation = _optionalSentence(question.explanation);
      final difficultyTag = question.difficultyTag.trim().isEmpty
          ? 'medium'
          : question.difficultyTag.trim();
      cleaned.add(
        AiQuizQuestionData(
          wordId: question.wordId,
          prompt: question.prompt.trim(),
          correctAnswer: question.correctAnswer.trim(),
          distractors: question.distractors.map((item) => item.trim()).toList(),
          explanation: explanation,
          difficultyTag: difficultyTag,
        ),
      );
    }

    if (cleaned.length != expectedCount) {
      return const [];
    }
    return cleaned;
  }

  String _stripCodeFences(String raw) {
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = fencePattern.firstMatch(raw);
    return match?.group(1)?.trim() ?? raw;
  }

  String? _extractJsonObject(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return null;
    }
    return raw.substring(start, end + 1);
  }

  String _fixCommonJsonIssues(String json) {
    return json
        .replaceAll(RegExp(r',\s*([}\]])'), r'$1')
        .replaceAll(RegExp(r"(?<!\\)'"), '"')
        .replaceAll(RegExp(r'//[^\n]*'), '');
  }

  List<String> _normalizeList(Object? raw, {required int minItems}) {
    final values = switch (raw) {
      List<dynamic>() => raw.map((item) => item.toString()).toList(),
      String() => raw
          .split(RegExp(r'[\r\n,;|]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      _ => <String>[],
    };

    final normalized = values
        .map(_normalizeSentence)
        .where((item) => item.isNotEmpty)
        .toList();

    return normalized.length >= minItems ? normalized : const [];
  }

  List<String> _removeDuplicates(List<String> values, {required String exclude}) {
    final results = <String>[];
    final seen = <String>{exclude.trim().toLowerCase()};
    for (final value in values) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      results.add(value.trim());
    }
    return results;
  }

  String _normalizeSentence(String raw, {String fallback = ''}) {
    final value = raw.trim();
    if (value.isEmpty) {
      return fallback;
    }
    return value.replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _optionalSentence(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}

import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../game/quiz_engine.dart';
import '../models/word.dart';
import '../models/user_level.dart';
import 'cactus_local_service.dart';
import 'device_capability.dart';

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

abstract class QuizAiGateway {
  void configure({
    String? openAIKey,
    String? geminiKey,
    String provider = 'gemini',
    String? localModelId,
  });

  Future<AiQuizGenerationResult> generateQuizSession({
    required List<Word> words,
    required QuizMode mode,
    required int sessionSize,
  });
}

class AIService implements QuizAiGateway {
  // Use a recent stable Gemini model endpoint
  static const String _openAIUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  final Dio _dio = Dio();
  final CactusLocalService _cactusService = CactusLocalService();
  String? _openAIKey;
  String? _geminiKey;
  String _provider = 'gemini';
  String? _onDeviceModelId;

  @override
  void configure({
    String? openAIKey,
    String? geminiKey,
    String provider = 'gemini',
    String? localModelId,
  }) {
    _openAIKey = openAIKey?.trim().isEmpty ?? true ? null : openAIKey!.trim();
    _geminiKey = geminiKey?.trim().isEmpty ?? true ? null : geminiKey!.trim();
    _provider = provider;
    _onDeviceModelId = localModelId;
    print(
        'AIService.configure: provider=$_provider localModel=$_onDeviceModelId '
        'openAI=${_openAIKey != null} gemini=${_geminiKey != null}');

    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  bool get isConfigured {
    if (_provider == 'openai') {
      if (_openAIKey == null)
        print('AIService: OpenAI selected but key is null');
      return _openAIKey != null;
    }
    if (_provider == 'gemini') {
      if (_geminiKey == null)
        print('AIService: Gemini selected but key is null');
      return _geminiKey != null;
    }
    if (_provider == 'cactus') return true;
    return false;
  }

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

  Future<AiSummaryResult> generateSummaryDetailed({
    required String word,
    required String? context,
    required UserLevel level,
    bool keepAlive = false,
  }) async {
    print('AIService.generateSummary: word="$word" provider=$_provider');
    if (_provider == 'openai' && _openAIKey != null) {
      final summary = await _generateWithOpenAI(word, context, level);
      return AiSummaryResult(
        summary: summary,
        failureStage: summary == null ? 'generation-failed' : null,
        errorMessage: summary == null ? 'Cloud generation failed' : null,
      );
    } else if (_provider == 'gemini' && _geminiKey != null) {
      final summary = await _generateWithGemini(word, context, level);
      return AiSummaryResult(
        summary: summary,
        failureStage: summary == null ? 'generation-failed' : null,
        errorMessage: summary == null ? 'Cloud generation failed' : null,
      );
    } else if (_provider == 'cactus') {
      return _generateWithCactusDetailed(
        word,
        context,
        level,
        keepAlive: keepAlive,
      );
    }
    print(
        'AIService: No valid configuration for provider "$_provider". Skipping.');
    return const AiSummaryResult(
      failureStage: 'not-configured',
      errorMessage: 'No valid AI provider is configured.',
    );
  }

  // ─── Cactus ──────────────────────────────────────────────────────────

  Future<AiSummaryResult> _generateWithCactusDetailed(
    String word,
    String? context,
    UserLevel level, {
    bool keepAlive = false,
  }) async {
    final modelId = _onDeviceModelId;
    if (modelId == null) {
      print('AIService: Cactus model not selected.');
      return const AiSummaryResult(
        failureStage: 'model-not-selected',
        errorMessage: 'Cactus model not selected.',
      );
    }
    final initWatch = Stopwatch()..start();
    final initResult = await _cactusService.initialize(modelId);
    initWatch.stop();
    if (!initResult.isSuccess) {
      print('AIService: Cactus init failed: ${initResult.message}');
      return AiSummaryResult(
        failureStage: 'load-failed',
        errorMessage: initResult.message ?? 'Cactus model failed to load.',
        loadMs: initWatch.elapsedMilliseconds,
      );
    }

    final device = DeviceCapability.instance;
    final systemPrompt = _buildCactusSystemPrompt(modelId);
    final userPrompt = _buildCactusUserPrompt(word, context, level, modelId);
    print('AIService: Calling Cactus ($modelId) for "$word" '
        'on ${device.tier.name} device...');

    final genResult = await _cactusService.generateText(
      userPrompt,
      systemPrompt: systemPrompt,
      maxTokens: 400,
      temperature: 0.0,
    );

    if (genResult.isSuccess && genResult.text != null) {
      print('Cactus: ${genResult.tokensGenerated} tokens in '
          '${genResult.totalTimeMs}ms (${genResult.tokensGenerated > 0 && genResult.totalTimeMs > 0 ? (genResult.tokensGenerated / (genResult.totalTimeMs / 1000)).toStringAsFixed(1) : '?'} tok/s)');
      final parsed = _parseSummary(genResult.text!);
      if (parsed == null) {
        return AiSummaryResult(
          failureStage: 'parse-failed',
          errorMessage: 'Cactus model returned invalid JSON.',
          loadMs: initWatch.elapsedMilliseconds,
          generateMs: genResult.totalTimeMs.round(),
        );
      }
      final summary = _cleanUsableSummary(word, parsed, modelId: modelId);
      if (summary != null) {
        final def = summary.definition;
        return AiSummaryResult(
          summary: WordSummary(
            definition: def,
            mainSay: summary.mainSay.isNotEmpty ? summary.mainSay : def,
            useCases: summary.useCases,
            similarWords: summary.similarWords,
            detailedSummary: summary.detailedSummary,
            generatedAt: summary.generatedAt,
          ),
          loadMs: initWatch.elapsedMilliseconds,
          generateMs: genResult.totalTimeMs.round(),
        );
      }
      final partialSummary =
          _buildBenchmarkPreviewSummary(word, parsed, modelId: modelId);
      return AiSummaryResult(
        partialSummary: partialSummary,
        failureStage: 'validation-rejected',
        errorMessage: _buildValidationErrorMessage(
          word,
          cleanedDefinition: cleanedDefinitionForPreview(parsed, normalizedWord: word.trim().toLowerCase(), modelId: modelId),
          useCases: _uniqueUsefulItems(
            _expandUseCaseCandidates(parsed.useCases)
                .map((item) => _shortenExample(
                      item,
                      maxWords: modelId == 'lfm-350m' ? 16 : 18,
                    ))
                .toList(),
            word.trim().toLowerCase(),
          ),
          similarWords: _cleanSimilarWords(
            _expandSimilarWordCandidates(parsed.similarWords),
            word.trim().toLowerCase(),
            preferPrecise: modelId == 'lfm-350m',
          ),
        ),
        loadMs: initWatch.elapsedMilliseconds,
        generateMs: genResult.totalTimeMs.round(),
      );
    }

    print('AIService: Cactus generation failed: ${genResult.message}');
    return AiSummaryResult(
      failureStage: genResult.error == CactusAiError.generationTimeout
          ? 'timed-out'
          : 'generation-failed',
      errorMessage: genResult.message ?? 'Cactus generation failed.',
      loadMs: initWatch.elapsedMilliseconds,
      generateMs: genResult.totalTimeMs.round(),
    );
  }

  // ─── OpenAI ──────────────────────────────────────────────────────────────

  Future<WordSummary?> _generateWithOpenAI(
    String word,
    String? context,
    UserLevel level,
  ) async {
    final prompt = _buildPrompt(word, context, level);
    try {
      print('AIService: Calling OpenAI for "$word"...');
      final response = await _dio.post(
        _openAIUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_openAIKey',
          },
        ),
        data: {
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a vocabulary assistant. Always respond with valid JSON only.'
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.5,
          'response_format': {'type': 'json_object'},
        },
      );

      print('AIService: OpenAI status ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = response.data;
        final content = data['choices'][0]['message']['content'] as String;
        return _parseSummary(content);
      }
    } on DioException catch (e) {
      print('AIService: OpenAI error: ${e.response?.data ?? e.message}');
    } catch (e) {
      print('AIService: OpenAI exception: $e');
    }
    return null;
  }

  // ─── Gemini ──────────────────────────────────────────────────────────────

  Future<WordSummary?> _generateWithGemini(
    String word,
    String? context,
    UserLevel level,
  ) async {
    final prompt = _buildPrompt(word, context, level);
    try {
      final url = '$_geminiBaseUrl?key=$_geminiKey';
      print('AIService: Calling Gemini (1.5-flash) for "$word"...');
      final response = await _dio.post(
        url,
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.5,
            'responseMimeType': 'application/json',
          },
        },
      );

      print('AIService: Gemini status ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final candidates = data['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('Gemini API returned no candidates');
        }

        final contentObj = candidates[0]['content'];
        if (contentObj == null ||
            contentObj['parts'] == null ||
            (contentObj['parts'] as List).isEmpty) {
          throw Exception('Gemini API returned empty content or parts');
        }

        final content = contentObj['parts'][0]['text'] as String;
        print('Gemini: Response received, parsing...');
        return _parseSummary(content);
      }
    } on DioException catch (e) {
      final errorData = e.response?.data;
      print('AIService: Gemini DioError: ${e.message}');
      if (errorData != null) {
        print('AIService: Gemini error details: $errorData');
      }
    } catch (e) {
      print('AIService: Gemini exception: $e');
    }
    return null;
  }

  // ─── Prompt ──────────────────────────────────────────────────────────────

  String _buildPrompt(String word, String? context, UserLevel level) {
    return _buildOnDeviceUserPrompt(word, context, level);
  }

  String _buildOnDeviceUserPrompt(
      String word, String? context, UserLevel level) {
    final ctx = context != null ? ' Used in: "$context".' : '';
    return '''
Create a vocabulary card for "$word" at ${level.displayName} level.$ctx

Return ONLY valid JSON with these keys:
- definition: one plain-English meaning
- useCases: three complete example sentences
- similarWords: three precise similar words

For "$word", write a short plain-English definition, three complete example
sentences with advanced vocabulary, and three precise similar words.

Rules:
- Fill every field.
- Use real synonyms, not the same word.
- Never copy schema labels or instructions into values.
- Keep each example sentence natural, and useful.
- Make the definition easy, but make the examples and synonyms more advanced.
- The similarWords values must be unique.
- If the word is an adjective, use adjective synonyms.
- Do not include markdown or explanation outside JSON.''';
  }

  String _buildCactusSystemPrompt(String modelId) {
    if (modelId == 'lfm-350m') {
      return 'You are a dictionary-style vocabulary assistant. Output ONLY valid JSON with '
          'exactly these keys: {"definition":"","useCases":["","",""],'
          '"similarWords":["","",""]}. '
          'Definition must be one clear dictionary-style sentence with a little nuance. '
          'It must be plain, direct, and not circular. '
          'Use cases must be natural sentences that use the target word clearly. '
          'Similar words should stay precise, advanced, and unique. '
          'Do not add any text before or after JSON.';
    }

    return 'You are a dictionary. Output ONLY valid JSON with ALL fields filled: '
        '{"definition":"","useCases":["","",""],"similarWords":["","",""]}. '
        'Always include exactly 3 use cases and 3 similar words. '
        'Do not repeat the input word. Do not add extra text before or after the JSON.';
  }

  String _buildCactusUserPrompt(
    String word,
    String? context,
    UserLevel level,
    String modelId,
  ) {
    if (modelId == 'lfm-350m') {
      final ctx = context != null ? ' Context: "$context".' : '';
      return '''
Create a vocabulary card for "$word".$ctx

Return ONLY valid JSON:
- definition: one dictionary-style meaning in plain English
- useCases: three short natural sentences using "$word"
- similarWords: three precise advanced similar words

Rules:
- Definition should sound simple and clear, like a dictionary-style note with a little nuance.
- Keep the definition to one sentence.
- Each example must be a complete sentence and use "$word" naturally.
- Keep examples concrete, polished, and not too long.
- Similar words should be richer and more advanced than the definition.
- Never copy instructions or schema labels into values.
- Do not include markdown or explanation outside JSON.''';
    }

    return _buildOnDeviceUserPrompt(word, context, level);
  }

  // ─── Parser ──────────────────────────────────────────────────────────────
  // With GBNF grammar enforced for local LLM, JSON parsing should always succeed.
  // The fallbacks below are kept as defense-in-depth for cloud providers.

  WordSummary? _parseSummary(String content) {
    try {
      String clean = content.trim();
      if (clean.isEmpty) {
        print('AIService: empty response from model');
        return null;
      }

      // Step 1: Remove markdown fences
      final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
      final match = fencePattern.firstMatch(clean);
      if (match != null) {
        clean = match.group(1)!.trim();
      }

      // Step 2: Try full JSON decode
      Map<String, dynamic>? data;
      try {
        // Find outermost JSON object
        final startIndex = clean.indexOf('{');
        final endIndex = clean.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          clean = clean.substring(startIndex, endIndex + 1);
        }
        data = jsonDecode(clean) as Map<String, dynamic>;
      } catch (_) {
        // Step 2b: Try fixing common local model JSON issues
        try {
          String fixed = _fixCommonJsonIssues(clean);
          final startIndex = fixed.indexOf('{');
          final endIndex = fixed.lastIndexOf('}');
          if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
            fixed = fixed.substring(startIndex, endIndex + 1);
          }
          data = jsonDecode(fixed) as Map<String, dynamic>;
        } catch (_) {
          // Step 3: Fallback — extract individual fields via regex when full JSON fails
          data = _extractFields(clean);
        }
      }

      if (data == null) {
        print('AIService: parse error — could not extract any fields');
        print(
            'AIService: raw content (first 500 chars): ${content.substring(0, content.length > 500 ? 500 : content.length)}');
        return null;
      }

      return WordSummary(
        definition: (data['definition'] as String?) ?? '',
        mainSay: (data['mainSay'] as String?) ?? '',
        useCases: _toStringList(data['useCases']),
        similarWords: _toStringList(data['similarWords']),
        detailedSummary: (data['detailedSummary'] as String?) ?? '',
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      print('AIService: parse error: $e');
      print(
          'AIService: raw content (first 500 chars): ${content.length > 500 ? content.substring(0, 500) : content}');
      return null;
    }
  }

  String _fixCommonJsonIssues(String json) {
    String fixed = json;
    // Remove trailing commas before } or ]
    fixed = fixed.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    // Replace single quotes with double quotes (but not escaped ones)
    fixed = fixed.replaceAll(RegExp(r"(?<!\\)'"), '"');
    // Remove comments like // ...
    fixed = fixed.replaceAll(RegExp(r'//[^\n]*'), '');
    // Remove trailing backslashes before closing quotes (common local model issue)
    fixed = fixed.replaceAll(RegExp(r'\\+\s*"'), '"');
    return fixed;
  }

  /// Fallback field extractor when JSON decode fails.
  /// Handles small local models that output near-JSON with minor issues.
  Map<String, dynamic>? _extractFields(String text) {
    String? extract(String key) {
      final reg = RegExp('"$key"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)"');
      final m = reg.firstMatch(text);
      return m?.group(1);
    }

    List<String> extractList(String key) {
      final reg = RegExp('"$key"\\s*:\\s*\\[([^\\]]*)\\]');
      final m = reg.firstMatch(text);
      if (m == null) return [];
      final items = m.group(1)!;
      return RegExp(r'"((?:[^"\\]|\\.)*)"')
          .allMatches(items)
          .map((e) => e.group(1)!)
          .toList();
    }

    final def = extract('definition');
    final mainSay = extract('mainSay');
    final useCases = extractList('useCases');
    final similarWords = extractList('similarWords');
    final detailedSummary = extract('detailedSummary');

    if (def == null && mainSay == null) return null;

    return {
      'definition': def ?? '',
      'mainSay': mainSay ?? '',
      'useCases': useCases,
      'similarWords': similarWords,
      'detailedSummary': detailedSummary ?? '',
    };
  }

  List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? [] : [trimmed];
    }
    return [];
  }

  WordSummary? _cleanUsableSummary(
    String word,
    WordSummary? summary, {
    String? modelId,
  }) {
    if (summary == null) return null;

    final normalizedWord = word.trim().toLowerCase();
    final prefersLfmDictionaryStyle = modelId == 'lfm-350m';
    final cleanedDefinition = _cleanDefinition(
      summary.definition,
      normalizedWord,
      preferDictionaryStyle: prefersLfmDictionaryStyle,
    );
    final normalizedDefinition = cleanedDefinition.toLowerCase();
    final useCases = _uniqueUsefulItems(
      _expandUseCaseCandidates(summary.useCases)
          .map((item) => _shortenExample(
                item,
                maxWords: prefersLfmDictionaryStyle ? 16 : 18,
              ))
          .toList(),
      normalizedWord,
    );
    final similarWords = _cleanSimilarWords(
      _expandSimilarWordCandidates(summary.similarWords),
      normalizedWord,
      preferPrecise: prefersLfmDictionaryStyle,
    );

    if (normalizedDefinition.isEmpty ||
        normalizedDefinition == normalizedWord ||
        normalizedDefinition == 'the word $normalizedWord') {
      print('AIService: rejected weak summary for "$word": bad definition');
      return null;
    }
    if (useCases.length < 2) {
      print('AIService: rejected weak summary for "$word": missing examples');
      return null;
    }
    if (similarWords.length < 2) {
      print('AIService: rejected weak summary for "$word": missing synonyms');
      return null;
    }

    return WordSummary(
      definition: cleanedDefinition,
      mainSay: summary.mainSay.trim(),
      useCases: useCases,
      similarWords: similarWords,
      detailedSummary: summary.detailedSummary.trim(),
      generatedAt: summary.generatedAt,
    );
  }

  String cleanedDefinitionForPreview(
    WordSummary summary, {
    required String normalizedWord,
    String? modelId,
  }) {
    return _cleanDefinition(
      summary.definition,
      normalizedWord,
      preferDictionaryStyle: modelId == 'lfm-350m',
    );
  }

  WordSummary? _buildBenchmarkPreviewSummary(
    String word,
    WordSummary? summary, {
    String? modelId,
  }) {
    if (summary == null) return null;

    final normalizedWord = word.trim().toLowerCase();
    final cleanedDefinition = cleanedDefinitionForPreview(
      summary,
      normalizedWord: normalizedWord,
      modelId: modelId,
    );
    final useCases = _uniqueUsefulItems(
      _expandUseCaseCandidates(summary.useCases)
          .map((item) => _shortenExample(
                item,
                maxWords: modelId == 'lfm-350m' ? 16 : 18,
              ))
          .toList(),
      normalizedWord,
    );
    final similarWords = _cleanSimilarWords(
      _expandSimilarWordCandidates(summary.similarWords),
      normalizedWord,
      preferPrecise: modelId == 'lfm-350m',
    );

    if (cleanedDefinition.trim().isEmpty &&
        useCases.isEmpty &&
        similarWords.isEmpty) {
      return null;
    }

    return WordSummary(
      definition: cleanedDefinition.trim().isNotEmpty
          ? cleanedDefinition.trim()
          : summary.definition.trim(),
      mainSay: summary.mainSay.trim(),
      useCases: useCases,
      similarWords: similarWords,
      detailedSummary: summary.detailedSummary.trim(),
      generatedAt: summary.generatedAt,
    );
  }

  String _buildValidationErrorMessage(
    String word, {
    required String cleanedDefinition,
    required List<String> useCases,
    required List<String> similarWords,
  }) {
    final normalizedWord = word.trim().toLowerCase();
    if (cleanedDefinition.isEmpty ||
        cleanedDefinition.toLowerCase() == normalizedWord ||
        cleanedDefinition.toLowerCase() == 'the word $normalizedWord') {
      return 'Validation rejected: weak definition.';
    }
    if (useCases.length < 2) {
      return 'Validation rejected: only ${useCases.length} usable example${useCases.length == 1 ? '' : 's'}.';
    }
    if (similarWords.length < 2) {
      return 'Validation rejected: only ${similarWords.length} usable similar word${similarWords.length == 1 ? '' : 's'}.';
    }
    return 'Generated summary did not pass validation.';
  }

  List<String> _uniqueUsefulItems(List<String> items, String normalizedWord) {
    final result = <String>[];
    final seen = <String>{};
    final copiedInstructionPattern = RegExp(
      r'natural sentence using|another natural sentence|third natural sentence|advanced natural sentence|precise similar words|plain-english definition|copy these instructions',
      caseSensitive: false,
    );

    for (final item in items) {
      final trimmed = item.trim();
      final normalized = trimmed.toLowerCase();
      if (trimmed.isEmpty ||
          normalized == normalizedWord ||
          copiedInstructionPattern.hasMatch(normalized) ||
          seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      result.add(trimmed);
    }
    return result;
  }

  List<String> _expandUseCaseCandidates(List<String> items) {
    final expanded = <String>[];

    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;

      final lines = trimmed
          .split(RegExp(r'[\r\n]+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();

      if (lines.length > 1) {
        expanded.addAll(lines);
      } else {
        expanded.add(trimmed);
      }
    }

    return expanded;
  }

  List<String> _expandSimilarWordCandidates(List<String> items) {
    final expanded = <String>[];

    for (final item in items) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed
          .split(RegExp(r'\s*[,;/]\s*'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();

      if (parts.length > 1) {
        expanded.addAll(parts);
      } else {
        expanded.add(trimmed);
      }
    }

    return expanded;
  }

  String _cleanDefinition(
    String value,
    String normalizedWord, {
    bool preferConcise = false,
    bool preferDictionaryStyle = false,
  }) {
    final sentences = value
        .trim()
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    var text = sentences.isNotEmpty ? sentences.first.trim() : value.trim();

    if (preferConcise) {
      final clauses = text
          .split(RegExp(r'[,;:]\s+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      for (final clause in clauses) {
        if (!_containsWordFamily(clause.toLowerCase(), normalizedWord)) {
          text = clause;
          break;
        }
      }
    }

    final words =
        text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    final maxWords = preferConcise
        ? 14
        : preferDictionaryStyle
            ? 22
            : 24;
    if (words.length > maxWords) {
      text = '${words.take(maxWords).join(' ')}.';
    }

    return text.trim();
  }

  List<String> _cleanSimilarWords(
    List<String> items,
    String normalizedWord, {
    bool preferPrecise = false,
  }) {
    final result = <String>[];
    final seen = <String>{};
    final copiedInstructionPattern = RegExp(
      r'natural sentence using|another natural sentence|third natural sentence|advanced natural sentence|precise similar words|plain-english definition|copy these instructions',
      caseSensitive: false,
    );

    for (final item in items) {
      final cleaned =
          item.trim().replaceAll(RegExp(r'^[\s,;:.-]+|[\s,;:.!-]+$'), '');
      if (cleaned.isEmpty) continue;

      final normalized = cleaned.toLowerCase();
      if (normalized == normalizedWord ||
          copiedInstructionPattern.hasMatch(normalized) ||
          seen.contains(normalized)) {
        continue;
      }

      if (preferPrecise) {
        final parts =
            cleaned.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
        if (parts.length > 4 ||
            _containsWordFamily(normalized, normalizedWord)) {
          continue;
        }
      }

      seen.add(normalized);
      result.add(cleaned);
    }

    return result;
  }

  String _shortenExample(String value, {int maxWords = 18}) {
    final sentences = value
        .trim()
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    final text = sentences.isNotEmpty ? sentences.first.trim() : value.trim();
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= maxWords) return text;
    return '${words.take(maxWords).join(' ')}.';
  }

  bool _containsWordFamily(String text, String normalizedWord) {
    final normalizedText = text.toLowerCase();
    if (normalizedWord.isEmpty || normalizedText.isEmpty) return false;
    if (normalizedText.contains(normalizedWord)) return true;
    if (normalizedWord.length < 5) return false;
    final stem = normalizedWord.substring(0, normalizedWord.length - 2);
    return stem.length >= 3 && normalizedText.contains(stem);
  }

  @visibleForTesting
  WordSummary? debugCleanSummaryForTesting({
    required String word,
    required WordSummary summary,
    String? modelId,
  }) {
    return _cleanUsableSummary(word, summary, modelId: modelId);
  }

  @visibleForTesting
  String debugBuildCactusSystemPromptForTesting(String modelId) {
    return _buildCactusSystemPrompt(modelId);
  }

  @visibleForTesting
  WordSummary? debugBuildBenchmarkPreviewForTesting({
    required String word,
    required WordSummary summary,
    String? modelId,
  }) {
    return _buildBenchmarkPreviewSummary(word, summary, modelId: modelId);
  }

  @visibleForTesting
  String debugBuildCactusUserPromptForTesting({
    required String word,
    required String? context,
    required UserLevel level,
    required String modelId,
  }) {
    return _buildCactusUserPrompt(word, context, level, modelId);
  }

  @override
  Future<AiQuizGenerationResult> generateQuizSession({
    required List<Word> words,
    required QuizMode mode,
    required int sessionSize,
  }) async {
    if (words.isEmpty) {
      return const AiQuizGenerationResult(
        failureStage: 'no-words',
        errorMessage: 'No eligible words available for quiz generation.',
      );
    }

    final systemPrompt = _buildQuizSystemPrompt();
    final userPrompt = _buildQuizUserPrompt(words, mode, sessionSize);

    if (_provider == 'openai' && _openAIKey != null) {
      return _generateQuizWithOpenAI(systemPrompt, userPrompt, words, sessionSize);
    }
    if (_provider == 'gemini' && _geminiKey != null) {
      return _generateQuizWithGemini(systemPrompt, userPrompt, words, sessionSize);
    }
    if (_provider == 'cactus') {
      return _generateQuizWithCactus(systemPrompt, userPrompt, words, sessionSize);
    }

    return const AiQuizGenerationResult(
      failureStage: 'not-configured',
      errorMessage: 'No valid AI provider is configured for quiz generation.',
    );
  }

  Future<AiQuizGenerationResult> _generateQuizWithOpenAI(
    String systemPrompt,
    String userPrompt,
    List<Word> words,
    int sessionSize,
  ) async {
    try {
      final response = await _dio.post(
        _openAIUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_openAIKey',
          },
        ),
        data: {
          'model': 'gpt-3.5-turbo',
          'temperature': 0.2,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
        },
      );
      final content =
          response.data['choices']?[0]?['message']?['content'] as String?;
      final parsed = _parseQuizGeneration(content);
      final cleaned = _validateQuizQuestions(
        parsed?.questions ?? const [],
        words: words,
        expectedCount: sessionSize,
      );
      if (cleaned.isEmpty) {
        return const AiQuizGenerationResult(
          failureStage: 'validation-failed',
          errorMessage: 'OpenAI quiz output did not pass validation.',
        );
      }
      return AiQuizGenerationResult(questions: cleaned);
    } catch (_) {
      return const AiQuizGenerationResult(
        failureStage: 'generation-failed',
        errorMessage: 'OpenAI quiz generation failed.',
      );
    }
  }

  Future<AiQuizGenerationResult> _generateQuizWithGemini(
    String systemPrompt,
    String userPrompt,
    List<Word> words,
    int sessionSize,
  ) async {
    try {
      final response = await _dio.post(
        '$_geminiBaseUrl?key=$_geminiKey',
        options: Options(headers: {'Content-Type': 'application/json'}),
        data: {
          'systemInstruction': {
            'parts': [
              {'text': systemPrompt}
            ]
          },
          'contents': [
            {
              'parts': [
                {'text': userPrompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
          },
        },
      );
      final content = response.data['candidates']?[0]?['content']?['parts']?[0]
          ?['text'] as String?;
      final parsed = _parseQuizGeneration(content);
      final cleaned = _validateQuizQuestions(
        parsed?.questions ?? const [],
        words: words,
        expectedCount: sessionSize,
      );
      if (cleaned.isEmpty) {
        return const AiQuizGenerationResult(
          failureStage: 'validation-failed',
          errorMessage: 'Gemini quiz output did not pass validation.',
        );
      }
      return AiQuizGenerationResult(questions: cleaned);
    } catch (_) {
      return const AiQuizGenerationResult(
        failureStage: 'generation-failed',
        errorMessage: 'Gemini quiz generation failed.',
      );
    }
  }

  Future<AiQuizGenerationResult> _generateQuizWithCactus(
    String systemPrompt,
    String userPrompt,
    List<Word> words,
    int sessionSize,
  ) async {
    final modelId = _onDeviceModelId;
    if (modelId == null) {
      return const AiQuizGenerationResult(
        failureStage: 'model-not-selected',
        errorMessage: 'Cactus model not selected.',
      );
    }

    final initResult = await _cactusService.initialize(modelId);
    if (!initResult.isSuccess) {
      return AiQuizGenerationResult(
        failureStage: 'load-failed',
        errorMessage: initResult.message ?? 'Cactus model failed to load.',
      );
    }

    final genResult = await _cactusService.generateText(
      userPrompt,
      systemPrompt: systemPrompt,
      maxTokens: 700,
      temperature: 0.0,
    );
    if (!genResult.isSuccess || genResult.text == null) {
      return AiQuizGenerationResult(
        failureStage: 'generation-failed',
        errorMessage: genResult.message ?? 'Cactus quiz generation failed.',
      );
    }

    final parsed = _parseQuizGeneration(genResult.text);
    final cleaned = _validateQuizQuestions(
      parsed?.questions ?? const [],
      words: words,
      expectedCount: sessionSize,
    );
    if (cleaned.isEmpty) {
      return const AiQuizGenerationResult(
        failureStage: 'validation-failed',
        errorMessage: 'Cactus quiz output did not pass validation.',
      );
    }
    return AiQuizGenerationResult(questions: cleaned);
  }

  String _buildQuizSystemPrompt() {
    return 'You are a vocabulary quiz generator. Output ONLY valid JSON in this shape: '
        '{"questions":[{"wordId":"","prompt":"","correctAnswer":"","distractors":["","",""],'
        '"explanation":"","difficultyTag":""}]}. '
        'Create concise multiple-choice vocabulary questions with one correct answer, '
        'three unique distractors, and an optional short explanation. '
        'Do not add markdown or extra commentary.';
  }

  String _buildQuizUserPrompt(
    List<Word> words,
    QuizMode mode,
    int sessionSize,
  ) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Create $sessionSize ${mode == QuizMode.speedRound ? 'speed-round' : 'multiple-choice'} vocabulary questions.',
    );
    buffer.writeln('Return ONLY valid JSON with a top-level "questions" array.');
    buffer.writeln('Each question must include: wordId, prompt, correctAnswer, distractors, explanation, difficultyTag.');
    buffer.writeln('Rules:');
    buffer.writeln('- Keep prompts short and easy to read on mobile.');
    buffer.writeln('- Use exactly 3 distractors per question.');
    buffer.writeln('- Make weak/new words easier and mastered words trickier.');
    buffer.writeln('- Prefer context-aware distractors when book context exists.');
    buffer.writeln('- Keep explanations under 18 words.');
    buffer.writeln('- Do not repeat the correct answer in distractors.');
    buffer.writeln('');
    buffer.writeln('Words:');

    for (final word in words.take(sessionSize)) {
      final difficulty = word.failureCount > word.successCount
          ? 'easy'
          : word.successCount >= 3
              ? 'hard'
              : 'medium';
      buffer.writeln(
        '- wordId: ${word.id}; text: ${word.text}; definition: ${word.summary?.definition ?? ''}; '
        'useCase: ${word.summary != null && word.summary!.useCases.isNotEmpty ? word.summary!.useCases.first : word.context ?? ''}; '
        'successCount: ${word.successCount}; failureCount: ${word.failureCount}; '
        'difficultyTarget: $difficulty; context: ${word.context ?? ''}',
      );
    }

    return buffer.toString();
  }

  AiQuizGenerationResult? _parseQuizGeneration(String? content) {
    if (content == null || content.trim().isEmpty) return null;

    try {
      var clean = content.trim();
      final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
      final match = fencePattern.firstMatch(clean);
      if (match != null) {
        clean = match.group(1)!.trim();
      }

      final startIndex = clean.indexOf('{');
      final endIndex = clean.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        clean = clean.substring(startIndex, endIndex + 1);
      }

      final data = jsonDecode(clean) as Map<String, dynamic>;
      final rawQuestions = data['questions'];
      if (rawQuestions is! List) return null;

      final questions = <AiQuizQuestionData>[];
      for (final item in rawQuestions) {
        if (item is! Map<String, dynamic>) continue;
        final distractors = _toStringList(item['distractors']);
        final difficultyTag = (item['difficultyTag'] as String?)?.trim();
        final wordId = (item['wordId'] as String? ?? '').trim();
        final prompt = (item['prompt'] as String? ?? '').trim();
        final correctAnswer = (item['correctAnswer'] as String? ?? '').trim();
        if (wordId.isEmpty || prompt.isEmpty || correctAnswer.isEmpty) {
          continue;
        }
        questions.add(
          AiQuizQuestionData(
            wordId: wordId,
            prompt: prompt,
            correctAnswer: correctAnswer,
            distractors: distractors,
            explanation: (item['explanation'] as String?)?.trim().isEmpty ?? true
                ? null
                : (item['explanation'] as String).trim(),
            difficultyTag: difficultyTag == null || difficultyTag.isEmpty
                ? 'medium'
                : difficultyTag,
          ),
        );
      }

      if (questions.isEmpty) return null;
      return AiQuizGenerationResult(questions: questions);
    } catch (_) {
      return null;
    }
  }

  List<AiQuizQuestionData> _validateQuizQuestions(
    List<AiQuizQuestionData> questions, {
    required List<Word> words,
    required int expectedCount,
  }) {
    final wordsById = {for (final word in words) word.id: word};
    final cleaned = <AiQuizQuestionData>[];

    for (final question in questions) {
      final sourceWord = wordsById[question.wordId];
      if (sourceWord == null) continue;
      if (question.prompt.trim().isEmpty || question.correctAnswer.trim().isEmpty) {
        continue;
      }
      if (question.distractors.length != 3) continue;

      final options = [
        question.correctAnswer.trim(),
        ...question.distractors.map((item) => item.trim()),
      ];
      final normalized = options.map((item) => item.toLowerCase()).toList();
      if (normalized.any((item) => item.isEmpty)) continue;
      if (normalized.toSet().length != 4) continue;

      cleaned.add(
        AiQuizQuestionData(
          wordId: question.wordId,
          prompt: question.prompt.trim(),
          correctAnswer: question.correctAnswer.trim(),
          distractors: question.distractors.map((item) => item.trim()).toList(),
          explanation: question.explanation?.trim().isEmpty ?? true
              ? null
              : question.explanation!.trim(),
          difficultyTag: question.difficultyTag.trim().isEmpty
              ? 'medium'
              : question.difficultyTag.trim(),
        ),
      );
    }

    if (cleaned.length != expectedCount) return const [];
    return cleaned;
  }

  @visibleForTesting
  String debugBuildQuizUserPromptForTesting({
    required List<Word> words,
    required QuizMode mode,
    required int sessionSize,
  }) {
    return _buildQuizUserPrompt(words, mode, sessionSize);
  }

  @visibleForTesting
  AiQuizGenerationResult? debugParseQuizGenerationForTesting(String raw) {
    return _parseQuizGeneration(raw);
  }

  @visibleForTesting
  List<AiQuizQuestionData> debugValidateQuizQuestionsForTesting({
    required List<AiQuizQuestionData> questions,
    required List<Word> words,
    required int expectedCount,
  }) {
    return _validateQuizQuestions(
      questions,
      words: words,
      expectedCount: expectedCount,
    );
  }

  // ─── Test connection ──────────────────────────────────────────────────────

  Future<bool> testConnection(String provider, String apiKey) async {
    try {
      if (provider == 'openai') {
        final response = await _dio.get(
          'https://api.openai.com/v1/models',
          options: Options(
            headers: {'Authorization': 'Bearer $apiKey'},
          ),
        );
        return response.statusCode == 200;
      } else if (provider == 'gemini') {
        final response = await _dio.post(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
          options: Options(
            headers: {'Content-Type': 'application/json'},
          ),
          data: {
            'contents': [
              {
                'parts': [
                  {'text': 'Say hi'}
                ]
              },
            ],
          },
        );
        return response.statusCode == 200;
      }
    } on DioException catch (e) {
      print('AIService.testConnection error: ${e.message}');
      print('AIService.testConnection response: ${e.response?.data}');
    } catch (e) {
      print('AIService.testConnection error: $e');
    }
    return false;
  }
}

import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import '../models/word.dart';
import '../models/user_level.dart';
import 'local_ai_service.dart';
import 'device_capability.dart';

class AIService {
  // Use a recent stable Gemini model endpoint
  static const String _openAIUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  final Dio _dio = Dio();
  final LocalAIService _localAiService = LocalAIService();
  String? _openAIKey;
  String? _geminiKey;
  String _provider = 'gemini';
  String _localModelId = 'qwen';

  void configure({
    String? openAIKey,
    String? geminiKey,
    String provider = 'gemini',
    String localModelId = 'qwen',
  }) {
    _openAIKey = openAIKey?.trim().isEmpty ?? true ? null : openAIKey!.trim();
    _geminiKey = geminiKey?.trim().isEmpty ?? true ? null : geminiKey!.trim();
    _provider = provider;
    _localModelId = localModelId;
    print('AIService.configure: provider=$_provider localModel=$_localModelId '
        'openAI=${_openAIKey != null} gemini=${_geminiKey != null}');

    // Add base options
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    if (_provider == 'local' && !_localAiService.isInitialized) {
      _localAiService.initialize(_localModelId);
    }
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
    if (_provider == 'local') return true;
    return false;
  }

  Future<WordSummary?> generateSummary({
    required String word,
    required String? context,
    required UserLevel level,
    bool keepAlive = false,
  }) async {
    print('AIService.generateSummary: word="$word" provider=$_provider');
    if (_provider == 'openai' && _openAIKey != null) {
      return _generateWithOpenAI(word, context, level);
    } else if (_provider == 'gemini' && _geminiKey != null) {
      return _generateWithGemini(word, context, level);
    } else if (_provider == 'local') {
      return _generateWithLocal(word, context, level, keepAlive: keepAlive);
    }
    print(
        'AIService: No valid configuration for provider "$_provider". Skipping.');
    return null;
  }

  // ─── Local LLM ──────────────────────────────────────────────────────────

  Future<WordSummary?> _generateWithLocal(
    String word,
    String? context,
    UserLevel level, {
    bool keepAlive = false,
  }) async {
    final initResult = await _localAiService.initialize(_localModelId);
    if (!initResult.isSuccess) {
      print('AIService: Local LLM init failed: ${initResult.message}');
      return null;
    }

    final device = DeviceCapability.instance;
    final systemPrompt = 'Respond with valid JSON only.';
    final userPrompt = _buildLocalUserPrompt(word, context, level);
    print('AIService: Calling Local LLM (${_localModelId}) for "$word" '
        'on ${device.tier.name} device (keepAlive=$keepAlive)...');

    final genResult = await _localAiService.generateText(
      userPrompt,
      systemPrompt: systemPrompt,
      keepAlive: keepAlive,
    );
    if (genResult.isSuccess && genResult.text != null) {
      final parsed = _parseSummary(genResult.text!);
      if (parsed != null) {
        final def = parsed.definition;
        return WordSummary(
          definition: def,
          mainSay: parsed.mainSay.isNotEmpty ? parsed.mainSay : def,
          useCases: parsed.useCases,
          similarWords: parsed.similarWords,
          detailedSummary: parsed.detailedSummary,
          generatedAt: parsed.generatedAt,
        );
      }
    }
    print('AIService: Local LLM generation failed: ${genResult.message}');
    return null;
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
    return _buildUserPrompt(word, context, level);
  }

  String _buildUserPrompt(String word, String? context, UserLevel level) {
    return '''Generate a JSON summary for the word "$word".
${context != null ? 'Context sentence: "$context"' : ''}
Target level: ${level.displayName}

Return ONLY a JSON object with exactly these keys:
{
  "definition": "concise definition appropriate for ${level.displayName} level",
  "mainSay": "the core concept in 1-2 simple sentences",
  "useCases": ["example 1", "example 2", "example 3"],
  "similarWords": ["word1", "word2", "word3", "word4", "word5"],
  "detailedSummary": "2-3 paragraph explanation for ${level.displayName} level"
}
Do NOT wrap in markdown or add any text outside the JSON object.''';
  }

  String _buildLocalUserPrompt(String word, String? context, UserLevel level) {
    final ctx = context != null ? ' Used in: "$context".' : '';
    return 'Define "$word" for ${level.displayName}.$ctx JSON:{"definition":"","useCases":["","",""],"similarWords":["","",""]}';
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
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) return [value];
    return [];
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

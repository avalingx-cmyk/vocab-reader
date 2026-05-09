import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import '../models/word.dart';
import '../models/user_level.dart';

class AIService {
  // Use a recent stable Gemini model endpoint
  static const String _openAIUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  final Dio _dio = Dio();
  String? _openAIKey;
  String? _geminiKey;
  String _provider = 'gemini';

  void configure({
    String? openAIKey,
    String? geminiKey,
    String provider = 'gemini',
  }) {
    _openAIKey = openAIKey?.trim().isEmpty ?? true ? null : openAIKey!.trim();
    _geminiKey = geminiKey?.trim().isEmpty ?? true ? null : geminiKey!.trim();
    _provider = provider;
    print('AIService.configure: provider=$_provider '
        'openAI=${_openAIKey != null} gemini=${_geminiKey != null}');
    
    // Add base options
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  bool get isConfigured {
    if (_provider == 'openai') return _openAIKey != null;
    if (_provider == 'gemini') return _geminiKey != null;
    return false;
  }

  Future<WordSummary?> generateSummary({
    required String word,
    required String? context,
    required UserLevel level,
  }) async {
    print('AIService.generateSummary: word="$word" provider=$_provider');
    if (_provider == 'openai' && _openAIKey != null) {
      return _generateWithOpenAI(word, context, level);
    } else if (_provider == 'gemini' && _geminiKey != null) {
      return _generateWithGemini(word, context, level);
    }
    print('AIService: No valid key for provider "$_provider". Skipping.');
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
              'content': 'You are a vocabulary assistant. Always respond with valid JSON only.'
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
      print('AIService: Calling Gemini (2.5-flash) for "$word"...');
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
          print('AIService: Gemini returned no candidates');
          return null;
        }
        final content = candidates[0]['content']['parts'][0]['text'] as String;
        return _parseSummary(content);
      }
    } on DioException catch (e) {
      print('AIService: Gemini error: ${e.response?.data ?? e.message}');
    } catch (e) {
      print('AIService: Gemini exception: $e');
    }
    return null;
  }

  // ─── Prompt ──────────────────────────────────────────────────────────────

  String _buildPrompt(String word, String? context, UserLevel level) {
    return '''You are a vocabulary teacher. Generate a JSON summary for the word "$word".
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

  // ─── Parser ──────────────────────────────────────────────────────────────

  WordSummary? _parseSummary(String content) {
    try {
      String clean = content.trim();
      // Strip markdown fences if present
      final fencePattern = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$');
      final match = fencePattern.firstMatch(clean);
      if (match != null) clean = match.group(1)!.trim();

      final data = jsonDecode(clean) as Map<String, dynamic>;

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
      print('AIService: raw content: $content');
      return null;
    }
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
              {'parts': [{'text': 'Say hi'}]},
            ],
          },
        );
        return response.statusCode == 200;
      }
    } on DioException catch (e) {
      print('AIService.testConnection error: ${e.message}');
    } catch (e) {
      print('AIService.testConnection error: $e');
    }
    return false;
  }
}

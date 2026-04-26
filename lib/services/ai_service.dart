import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/word.dart';
import '../models/user_level.dart';

class AIService {
  static const String _openAIUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  String? _openAIKey;
  String? _geminiKey;
  String _provider = 'openai'; // 'openai' or 'gemini'

  void configure({
    String? openAIKey,
    String? geminiKey,
    String provider = 'openai',
  }) {
    _openAIKey = openAIKey;
    _geminiKey = geminiKey;
    _provider = provider;
  }

  Future<WordSummary?> generateSummary({
    required String word,
    required String? context,
    required UserLevel level,
  }) async {
    if (_provider == 'openai' && _openAIKey != null) {
      return await _generateWithOpenAI(word, context, level);
    } else if (_provider == 'gemini' && _geminiKey != null) {
      return await _generateWithGemini(word, context, level);
    }
    return null;
  }

  Future<WordSummary?> _generateWithOpenAI(
    String word,
    String? context,
    UserLevel level,
  ) async {
    final prompt = _buildPrompt(word, context, level);

    try {
      final response = await http.post(
        Uri.parse(_openAIUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAIKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'system', 'content': 'You are a helpful vocabulary assistant.'},
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return _parseSummary(content);
      }
    } catch (e) {
      print('OpenAI error: $e');
    }
    return null;
  }

  Future<WordSummary?> _generateWithGemini(
    String word,
    String? context,
    UserLevel level,
  ) async {
    final prompt = _buildPrompt(word, context, level);

    try {
      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$_geminiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return _parseSummary(content);
      }
    } catch (e) {
      print('Gemini error: $e');
    }
    return null;
  }

  String _buildPrompt(String word, String? context, UserLevel level) {
    return '''
Word: $word
${context != null ? 'Context: $context' : ''}
User Level: ${level.name}

Generate a vocabulary summary with the following sections:

1. DEFINITION: A clear, concise definition appropriate for ${level.displayName} level.

2. MAIN SAY: The core concept in 1-2 simple sentences.

3. USE CASES: 3 real-world examples or scenarios where this word is used.

4. SIMILAR WORDS: 5-7 synonyms, antonyms, or related words appropriate for ${level.displayName} level.

5. DETAILED SUMMARY: A comprehensive explanation (2-3 paragraphs) suitable for ${level.displayName} level.

Format your response like this:
DEFINITION: [definition]
MAIN SAY: [main concept]
USE CASES:
- [example 1]
- [example 2]
- [example 3]
SIMILAR WORDS: [word1], [word2], [word3], [word4], [word5], [word6], [word7]
DETAILED SUMMARY: [detailed explanation]
''';
  }

  WordSummary? _parseSummary(String content) {
    try {
      String? definition;
      String? mainSay;
      List<String> useCases = [];
      List<String> similarWords = [];
      String? detailedSummary;

      final lines = content.split('\n');
      String currentSection = '';
      StringBuffer detailBuffer = StringBuffer();

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        if (line.startsWith('DEFINITION:')) {
          definition = line.substring('DEFINITION:'.length).trim();
          currentSection = 'definition';
        } else if (line.startsWith('MAIN SAY:')) {
          mainSay = line.substring('MAIN SAY:'.length).trim();
          currentSection = 'mainsay';
        } else if (line.startsWith('USE CASES:')) {
          currentSection = 'usecases';
        } else if (line.startsWith('SIMILAR WORDS:')) {
          // Process any collected detail
          if (detailBuffer.isNotEmpty && detailedSummary == null) {
            detailedSummary = detailBuffer.toString().trim();
          }
          
          final wordsText = line.substring('SIMILAR WORDS:'.length).trim();
          similarWords = wordsText
              .split(',')
              .map((w) => w.trim())
              .where((w) => w.isNotEmpty)
              .toList();
          currentSection = 'similar';
        } else if (line.startsWith('DETAILED SUMMARY:')) {
          // Process any collected detail
          if (detailBuffer.isNotEmpty && detailedSummary == null) {
            detailedSummary = detailBuffer.toString().trim();
          }
          
          final summaryText = line.substring('DETAILED SUMMARY:'.length).trim();
          detailBuffer = StringBuffer(summaryText);
          currentSection = 'summary';
        } else if (line.startsWith('-')) {
          if (currentSection == 'usecases') {
            useCases.add(line.substring(1).trim());
          }
        } else if (currentSection == 'summary') {
          detailBuffer.writeln();
          detailBuffer.write(line);
        }
      }

      // Get remaining detail
      if (detailBuffer.isNotEmpty) {
        detailedSummary = detailBuffer.toString().trim();
      }

      if (definition != null && mainSay != null && detailedSummary != null) {
        return WordSummary(
          definition: definition,
          mainSay: mainSay,
          useCases: useCases,
          similarWords: similarWords,
          detailedSummary: detailedSummary,
          generatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      print('Parse error: $e');
    }
    return null;
  }

  Future<bool> testConnection(String provider, String apiKey) async {
    try {
      if (provider == 'openai') {
        final response = await http.get(
          Uri.parse('https://api.openai.com/v1/models'),
          headers: {'Authorization': 'Bearer $apiKey'},
        );
        return response.statusCode == 200;
      } else if (provider == 'gemini') {
        final response = await http.post(
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [{'parts': [{'text': 'Hello'}]}],
          }),
        );
        return response.statusCode == 200;
      }
    } catch (e) {
      print('Test connection error: $e');
    }
    return false;
  }
}

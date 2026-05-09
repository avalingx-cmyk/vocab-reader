import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'AIzaSyBcg8KgNcW_PstMHdSvNYaD5QOY7Kj2x5I';
  
  final modelsToTest = [
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-3.1-flash-lite',
  ];

  for (final model in modelsToTest) {
    print('Testing $model...');
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Hello'}
              ]
            }
          ]
        }),
      );

      print('  Status: ${response.statusCode}');
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        print('  Error Message: ${body['error']['message']}');
      } else {
        print('  Success!');
      }
    } catch (e) {
      print('  Error: $e');
    }
  }
}

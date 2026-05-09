import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'AIzaSyBcg8KgNcW_PstMHdSvNYaD5QOY7Kj2x5I';
  const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$apiKey';

  print('Testing Gemini API with gemini-1.5-flash-latest...');
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

    print('Status: ${response.statusCode}');
    final body = jsonDecode(response.body);
    if (response.statusCode != 200) {
      print('Error Message: ${body['error']['message']}');
    } else {
      print('Success!');
    }
  } catch (e) {
    print('Error: $e');
  }
}

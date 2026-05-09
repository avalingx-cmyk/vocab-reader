import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = 'AIzaSyBcg8KgNcW_PstMHdSvNYaD5QOY7Kj2x5I';
  const url = 'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';

  print('Listing available models...');
  try {
    final response = await http.get(Uri.parse(url));

    print('Status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final models = body['models'] as List;
      for (final model in models) {
        if (model['name'].contains('gemini')) {
          print('- ${model['name']}');
        }
      }
    } else {
      print('Error: ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}

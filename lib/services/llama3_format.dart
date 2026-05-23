import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class Llama3Format extends PromptFormat {
  Llama3Format()
      : super(PromptFormatType.raw,
            inputSequence: '<|start_header_id|>user<|end_header_id|>\n\n',
            outputSequence: '<|start_header_id|>assistant<|end_header_id|>\n\n',
            systemSequence: '<|start_header_id|>system<|end_header_id|>\n\n',
            stopSequence: '<|eot_id|>');

  @override
  String formatPrompt(String prompt) {
    return '$inputSequence$prompt$stopSequence$outputSequence';
  }

  @override
  String formatMessages(List<Map<String, dynamic>> messages) {
    final buffer = StringBuffer();

    for (final message in messages) {
      final role = message['role'];
      final content = message['content'];

      if (role == 'system') {
        buffer.write('$systemSequence$content$stopSequence');
      } else if (role == 'user') {
        buffer.write('$inputSequence$content$stopSequence');
      } else if (role == 'assistant') {
        buffer.write('$outputSequence$content$stopSequence');
      }
    }

    buffer.write(outputSequence);

    return buffer.toString();
  }
}

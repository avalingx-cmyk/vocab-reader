import 'package:bookbeam/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('benchmarkContextForAttempt', () {
    test('keeps user context when provided', () {
      final context = benchmarkContextForAttempt(
        word: 'ephemeral',
        userContext: 'The joy felt ephemeral after the news arrived.',
        attempt: 2,
        previousFailureStage: 'validation-rejected',
      );

      expect(
        context,
        'The joy felt ephemeral after the news arrived.',
      );
    });

    test('uses empty context on first attempt when user did not provide one',
        () {
      final context = benchmarkContextForAttempt(
        word: 'ephemeral',
        userContext: '',
        attempt: 1,
        previousFailureStage: null,
      );

      expect(context, isNull);
    });

    test('adds fallback context on retry after parse or validation failure',
        () {
      final context = benchmarkContextForAttempt(
        word: 'ephemeral',
        userContext: '',
        attempt: 2,
        previousFailureStage: 'validation-rejected',
      );

      expect(context, isNotNull);
      expect(context!, contains('ephemeral'));
    });
  });
}

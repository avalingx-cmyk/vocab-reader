import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/models/word.dart';
import 'package:bookbeam/providers/settings_provider.dart';
import 'package:bookbeam/providers/word_provider.dart';
import 'package:bookbeam/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('WordsTab does not show the keep the momentum card',
      (tester) async {
    final words = [
      _word(
        id: 'w1',
        text: 'ephemeral',
        bookName: 'Novel',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      _word(
        id: 'w2',
        text: 'meticulous',
        bookName: 'Novel',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredWordsProvider(null).overrideWith((ref) => words),
          wordListProvider(null)
              .overrideWith((ref) async => words),
          settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WordsTab(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Keep the momentum!'), findsNothing);
    expect(find.text('7-Day Activity'), findsOneWidget);
    expect(find.text('Recent Words'), findsOneWidget);
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier() : super(loadFromStorage: false) {
    state = const SettingsState(
      weeklyGoal: 20,
      isLoading: false,
    );
  }
}

Word _word({
  required String id,
  required String text,
  required String bookName,
  required DateTime createdAt,
}) {
  return Word(
    id: id,
    text: text,
    bookName: bookName,
    userLevel: UserLevel.beginner,
    summary: WordSummary(
      definition: '$text definition',
      mainSay: '$text definition',
      useCases: const ['Example sentence.'],
      similarWords: const ['brief', 'precise', 'clear'],
      detailedSummary: '$text definition',
      generatedAt: DateTime(2025, 1, 1),
    ),
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

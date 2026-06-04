import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/providers/book_provider.dart';
import 'package:bookbeam/providers/model_readiness_provider.dart';
import 'package:bookbeam/providers/settings_provider.dart';
import 'package:bookbeam/screens/add_word_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preselects the passed book in the add word flow', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
          bookListProvider.overrideWith((ref) async => [
                BookInfo(
                  id: 'book-1',
                  name: 'Meditations',
                  wordCount: 3,
                  pendingCount: 0,
                  lastAccessed: DateTime(2026, 1, 1),
                ),
              ]),
        ],
        child: const MaterialApp(
          home: AddWordScreen(
            initialBookId: 'book-1',
            initialBookName: 'Meditations',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Meditations'), findsOneWidget);
    expect(find.text('Select book'), findsNothing);
  });

  test('shows settings action when the model is not ready', () {
    final snackBar = buildWordSavedSnackBar(
      modelState: const ModelReadinessState(
        status: ModelReadinessStatus.notDownloaded,
        title: 'Download offline AI',
        message: 'Missing model.',
        ctaLabel: 'Download Model',
      ),
      onOpenSettings: () {},
    );

    expect(
      (snackBar.content as Text).data,
      'Word saved. Download or repair the offline AI in Settings to create the explanation.',
    );
    expect(snackBar.action?.label, 'Open Settings');
  });

  test('does not show settings action when the model is ready', () {
    final snackBar = buildWordSavedSnackBar(
      modelState: const ModelReadinessState(
        status: ModelReadinessStatus.ready,
        title: 'Offline AI is ready',
        message: 'Ready.',
        ctaLabel: 'Repair Model',
      ),
      onOpenSettings: () {},
    );

    expect(
      (snackBar.content as Text).data,
      'Word saved. BookBeam is creating the explanation now.',
    );
    expect(snackBar.action, isNull);
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier() : super(loadFromStorage: false) {
    state = const SettingsState(
      userLevel: UserLevel.beginner,
      cactusModelId: 'qwen3-0.6b',
      isLoading: false,
    );
  }
}

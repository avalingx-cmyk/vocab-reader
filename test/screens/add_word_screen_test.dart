import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/providers/book_provider.dart';
import 'package:bookbeam/providers/model_readiness_provider.dart';
import 'package:bookbeam/providers/settings_provider.dart';
import 'package:bookbeam/providers/theme_provider.dart';
import 'package:bookbeam/screens/add_word_screen.dart';
import 'package:bookbeam/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('preselects the passed book in the add word flow',
      (tester) async {
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
    final notice = WordSavedNotice.fromModelState(
      const ModelReadinessState(
        status: ModelReadinessStatus.notDownloaded,
        title: 'Download offline AI',
        message: 'Missing model.',
        ctaLabel: 'Download Model',
      ),
    );
    final snackBar = buildWordSavedSnackBar(
      notice: notice,
      onOpenSettings: () {},
    );

    expect(
      (snackBar.content as Text).data,
      'Word saved. Download or repair the offline AI in Settings to create the explanation.',
    );
    expect(notice.opensSettings, isTrue);
    expect(snackBar.action?.label, 'Open Settings');
    expect(snackBar.duration, const Duration(seconds: 6));
  });

  test('does not show settings action when the model is ready', () {
    final notice = WordSavedNotice.fromModelState(
      const ModelReadinessState(
        status: ModelReadinessStatus.ready,
        title: 'Offline AI is ready',
        message: 'Ready.',
        ctaLabel: 'Repair Model',
      ),
    );
    final snackBar = buildWordSavedSnackBar(
      notice: notice,
      onOpenSettings: () {},
    );

    expect(
      (snackBar.content as Text).data,
      'Word saved. BookBeam is creating the explanation now.',
    );
    expect(notice.opensSettings, isFalse);
    expect(snackBar.action, isNull);
  });

  testWidgets('warning snackbar opens settings and closes itself',
      (tester) async {
    final notice = WordSavedNotice.fromModelState(
      const ModelReadinessState(
        status: ModelReadinessStatus.notDownloaded,
        title: 'Download offline AI',
        message: 'Missing model.',
        ctaLabel: 'Download Model',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
          themeModeProvider.overrideWith((ref) => _FakeThemeModeNotifier()),
          modelReadinessProvider.overrideWith(
            (ref) => _FakeModelReadinessNotifier(
              ref,
              const ModelReadinessState(
                status: ModelReadinessStatus.notDownloaded,
                title: 'Download offline AI',
                message: 'Missing model.',
                ctaLabel: 'Download Model',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();

    final scaffoldContext = tester.element(find.byType(Scaffold));
    showWordSavedNotice(scaffoldContext, notice);
    await tester.pumpAndSettle();

    expect(find.text('Open Settings'), findsOneWidget);

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Open Settings'), findsNothing);
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

class _FakeModelReadinessNotifier extends ModelReadinessNotifier {
  _FakeModelReadinessNotifier(super.ref, ModelReadinessState state) : super() {
    this.state = state;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> download() async {}

  @override
  Future<void> repair() async {}

  @override
  void cancelDownload() {}
}

class _FakeThemeModeNotifier extends ThemeModeNotifier {
  _FakeThemeModeNotifier() : super() {
    state = ThemeMode.system;
  }

  @override
  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
  }
}

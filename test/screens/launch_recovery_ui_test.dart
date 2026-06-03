import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/providers/model_readiness_provider.dart';
import 'package:bookbeam/providers/settings_provider.dart';
import 'package:bookbeam/providers/word_provider.dart';
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

  testWidgets('WordsTab shows missing-model guidance card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredWordsProvider(null).overrideWith((ref) => []),
          wordListProvider(null).overrideWith((ref) async => []),
          settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
          modelReadinessProvider.overrideWith(
            (ref) => _FakeModelReadinessNotifier(
              ref,
              const ModelReadinessState(
                status: ModelReadinessStatus.notDownloaded,
                title: 'Download offline AI',
                message:
                    'Download the local model before BookBeam can create word explanations.',
                ctaLabel: 'Download Model',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WordsTab()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Your Library is Empty'), findsOneWidget);
    expect(find.textContaining('Download the offline AI'), findsOneWidget);
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

import 'package:bookbeam/providers/diagnostics_provider.dart';
import 'package:bookbeam/providers/model_readiness_provider.dart';
import 'package:bookbeam/providers/settings_provider.dart';
import 'package:bookbeam/providers/theme_provider.dart';
import 'package:bookbeam/screens/settings_screen.dart';
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

  testWidgets('settings hides support and diagnostics section', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _FakeSettingsNotifier()),
          themeModeProvider.overrideWith((ref) => _FakeThemeModeNotifier()),
          modelReadinessProvider.overrideWith(
            (ref) => _FakeModelReadinessNotifier(
              ref,
              const ModelReadinessState(
                status: ModelReadinessStatus.ready,
                title: 'Offline AI is ready',
                message: 'New words can be summarized on this device.',
                ctaLabel: 'Repair Model',
              ),
            ),
          ),
          recentAnalyticsEventsProvider.overrideWith((ref) async => []),
          recentErrorLogsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('OFFLINE AI'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('SUPPORT & DIAGNOSTICS'), findsNothing);
    expect(find.text('Recent activity'), findsNothing);
    expect(find.text('Recent issues'), findsNothing);
    expect(find.text('OFFLINE AI'), findsOneWidget);
  });
}

class _FakeSettingsNotifier extends SettingsNotifier {
  _FakeSettingsNotifier() : super(loadFromStorage: false) {
    state = const SettingsState(
      isLoading: false,
      cactusModelId: 'qwen3-0.6b',
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

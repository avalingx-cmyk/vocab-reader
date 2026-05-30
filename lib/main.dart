import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'services/database_service.dart';
import 'providers/connectivity_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env – failure is non-fatal (keys may be entered via Settings UI)
  try {
    await dotenv.load(fileName: '.env');
    print('main: .env loaded successfully');
  } catch (e) {
    print('main: .env not found or failed to load ($e). '
        'API keys must be entered via Settings.');
  }

  // Init DB
  await DatabaseService.instance.init();
  print('main: Database initialised');

  // Start connectivity monitoring (singleton)
  ConnectivityChecker.instance.startChecking();
  print('main: Connectivity checker started');

  runApp(const ProviderScope(child: VocabReaderApp()));
}

class VocabReaderApp extends ConsumerWidget {
  const VocabReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'BookBeam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const _AppStartup(),
    );
  }
}

class _AppStartup extends ConsumerStatefulWidget {
  const _AppStartup();

  @override
  ConsumerState<_AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends ConsumerState<_AppStartup> {
  bool _isFirstLaunch = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final onboardingComplete =
        await DatabaseService.instance.getSetting('onboarding_complete');
    if (mounted) {
      setState(() {
        _isFirstLaunch = onboardingComplete != 'true';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isFirstLaunch ? const OnboardingScreen() : const HomeScreen();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_level.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import 'home_screen.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  UserLevel _selectedLevel = UserLevel.beginner;

  void _completeOnboarding() async {
    await DatabaseService.instance.setSetting(
      'user_level',
      _selectedLevel.name,
    );
    await DatabaseService.instance.clearLegacyAiSettings();
    await DatabaseService.instance.setSetting('onboarding_complete', 'true');
    await LocalAnalyticsService.instance.track(
      'onboarding.completed',
      payload: {'learnerLevel': _selectedLevel.name},
    );

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue.withValues(alpha: 0.05),
                    Theme.of(context).colorScheme.surface,
                    AppTheme.accentAmber.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),

          // Floating Shapes for Premium Feel
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      24,
                ),
                child: Column(
                  children: [
                    _buildLandingPage(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 32.0,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _completeOnboarding,
                          child: const Text('Get Started'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandingPage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 80,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'BookBeam',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your intelligent reading companion. Capture words, master meaning.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          RadioGroup<UserLevel>(
            groupValue: _selectedLevel,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedLevel = value);
              }
            },
            child: Column(
              children: UserLevel.values
                  .map(
                    (level) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildLevelCard(level),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(UserLevel level) {
    final selected = level == _selectedLevel;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              selected ? AppTheme.primaryBlue : Theme.of(context).dividerColor,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: RadioListTile<UserLevel>(
          value: level,
          activeColor: AppTheme.primaryBlue,
          title: Text(
            level.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            level.description,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

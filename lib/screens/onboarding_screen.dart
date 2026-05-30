import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import 'home_screen.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  void _completeOnboarding() async {
    await DatabaseService.instance.setSetting(
      'user_level',
      'beginner',
    );
    await DatabaseService.instance.setSetting('onboarding_complete', 'true');
    
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
            child: Column(
              children: [
                Expanded(
                  child: _buildLandingPage(),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _completeOnboarding,
                          child: const Text('Get Started'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
        mainAxisAlignment: MainAxisAlignment.center,
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
          _buildFeatureCard(
            icon: Icons.bolt_rounded,
            title: 'AI-Powered Insights',
            desc: 'Get smart summaries and use cases instantly.',
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            icon: Icons.layers_rounded,
            title: 'Clear Explanations',
            desc: 'Balanced summaries tuned for everyday learning.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

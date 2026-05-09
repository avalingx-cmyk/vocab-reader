import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_level.dart';
import '../services/database_service.dart';
import 'home_screen.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentPage = 0;
  UserLevel _selectedLevel = UserLevel.beginner;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _completeOnboarding() async {
    await DatabaseService.instance.setSetting(
      'user_level',
      _selectedLevel.name,
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
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      _buildLandingPage(),
                      _buildLevelSelectionPage(),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    children: [
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildIndicator(0),
                          const SizedBox(width: 8),
                          _buildIndicator(1),
                        ],
                      ),
                      const SizedBox(height: 32),
                      
                      Row(
                        children: [
                          if (_currentPage > 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutQuart,
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  side: const BorderSide(color: AppTheme.primaryBlue),
                                ),
                                child: const Text('Back'),
                              ),
                            ),
                          if (_currentPage > 0) const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_currentPage < 1) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOutQuart,
                                  );
                                } else {
                                  _completeOnboarding();
                                }
                              },
                              child: Text(_currentPage < 1 ? 'Next' : 'Get Started'),
                            ),
                          ),
                        ],
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

  Widget _buildIndicator(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryBlue : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
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
            title: 'Personalized Levels',
            desc: 'Content tailored to your vocabulary knowledge.',
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

  Widget _buildLevelSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Master Your Journey',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Select your current vocabulary level to help us tailor AI summaries for you.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: UserLevel.values.map((level) => _buildLevelOption(level)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelOption(UserLevel level) {
    final isSelected = _selectedLevel == level;
    return GestureDetector(
      onTap: () => setState(() => _selectedLevel = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Theme.of(context).colorScheme.surfaceContainerHighest,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8) : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

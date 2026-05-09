import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/quiz_engine.dart';
import '../theme/app_theme.dart';
import 'quiz_mode_screen.dart';

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _ModeSelectionView();
  }
}

// ── Mode Selection ─────────────────────────────────────────────────────────
class _ModeSelectionView extends ConsumerWidget {
  const _ModeSelectionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = [
      const _ModeInfo(
        mode: QuizMode.flashcard,
        title: 'Flashcards',
        subtitle: 'Flip cards & self-assess',
        icon: Icons.style_rounded,
        color: AppTheme.primaryBlue,
        difficulty: 'Easy',
        duration: '~3 min',
      ),
      const _ModeInfo(
        mode: QuizMode.multipleChoice,
        title: 'Multiple Choice',
        subtitle: 'Pick the right definition',
        icon: Icons.checklist_rounded,
        color: Color(0xFF7C3AED),
        difficulty: 'Medium',
        duration: '~4 min',
      ),
      const _ModeInfo(
        mode: QuizMode.spellingBee,
        title: 'Spelling Bee',
        subtitle: 'Type the word from its meaning',
        icon: Icons.spellcheck_rounded,
        color: Color(0xFF0891B2),
        difficulty: 'Hard',
        duration: '~5 min',
      ),
      const _ModeInfo(
        mode: QuizMode.speedRound,
        title: 'Speed Round',
        subtitle: '5 seconds per question!',
        icon: Icons.bolt_rounded,
        color: AppTheme.accentAmber,
        difficulty: 'Hard',
        duration: '~2 min',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Word Games',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a game mode to practice your vocabulary',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Mode cards
          ...modes.map((info) => _ModeCard(
                info: info,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizModeScreen(mode: info.mode),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _ModeInfo {
  final QuizMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String difficulty;
  final String duration;

  const _ModeInfo({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.difficulty,
    required this.duration,
  });
}

class _ModeCard extends StatelessWidget {
  final _ModeInfo info;
  final VoidCallback onTap;

  const _ModeCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: info.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: info.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(info.icon, color: info.color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          info.subtitle,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _Chip(label: info.difficulty, color: info.color),
                            const SizedBox(width: 8),
                            _Chip(
                              label: info.duration,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

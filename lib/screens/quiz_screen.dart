import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/quiz_engine.dart';
import '../providers/quiz_provider.dart';
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
    final dueWords = ref.watch(dueWordsProvider);
    final newWords = ref.watch(newStudyWordsProvider);
    final masteredWords = ref.watch(masteredWordsProvider);
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

          _ReviewOverviewSection(
            dueWords: dueWords,
            newWords: newWords,
            masteredWords: masteredWords,
          ),
          const SizedBox(height: 24),

          if (dueWords.isNotEmpty) ...[
            _StudyTodayCard(dueCount: dueWords.length),
            const SizedBox(height: 20),
            _ModeCard(
              info: const _ModeInfo(
                mode: QuizMode.flashcard,
                title: 'Study Today',
                subtitle: 'Review words due right now',
                icon: Icons.event_repeat_rounded,
                color: Color(0xFF16A34A),
                difficulty: 'Due now',
                duration: '~3 min',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => QuizModeScreen(
                    mode: QuizMode.flashcard,
                    dueWords: dueWords,
                  ),
                ),
              ),
            ),
          ],

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

class _ReviewOverviewSection extends StatelessWidget {
  final List dueWords;
  final List newWords;
  final List masteredWords;

  const _ReviewOverviewSection({
    required this.dueWords,
    required this.newWords,
    required this.masteredWords,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review Library',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Track what is due, what is new, and what you have mastered.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _ReviewStatCard(
                title: 'Due',
                value: dueWords.length.toString(),
                color: const Color(0xFF16A34A),
                icon: Icons.event_repeat_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReviewStatCard(
                title: 'New',
                value: newWords.length.toString(),
                color: AppTheme.primaryBlue,
                icon: Icons.fiber_new_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReviewStatCard(
                title: 'Mastered',
                value: masteredWords.length.toString(),
                color: const Color(0xFF7C3AED),
                icon: Icons.workspace_premium_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _ReviewStatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyTodayCard extends StatelessWidget {
  final int dueCount;
  const _StudyTodayCard({required this.dueCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF16A34A),
            const Color(0xFF22C55E).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3316A34A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.auto_stories_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Study Today',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$dueCount word${dueCount == 1 ? '' : 's'} due for review',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
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

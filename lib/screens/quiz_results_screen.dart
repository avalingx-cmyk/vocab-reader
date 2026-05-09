import 'package:flutter/material.dart';
import '../game/quiz_engine.dart';
import '../theme/app_theme.dart';
import 'quiz_mode_screen.dart';

class QuizResultsScreen extends StatelessWidget {
  final QuizSession session;
  final QuizMode mode;

  const QuizResultsScreen({
    super.key,
    required this.session,
    required this.mode,
  });

  Color get _modeColor {
    switch (mode) {
      case QuizMode.flashcard: return AppTheme.primaryBlue;
      case QuizMode.multipleChoice: return const Color(0xFF7C3AED);
      case QuizMode.spellingBee: return const Color(0xFF0891B2);
      case QuizMode.speedRound: return AppTheme.accentAmber;
    }
  }

  String get _emoji {
    final pct = session.accuracy;
    if (pct >= 0.9) return '🏆';
    if (pct >= 0.7) return '🌟';
    if (pct >= 0.5) return '💪';
    return '📖';
  }

  @override
  Widget build(BuildContext context) {
    final pct = session.accuracy;
    final xp = session.xpEarned;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Big emoji
              Text(_emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              Text(
                _title(pct),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _subtitle(pct),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),

              // Score card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_modeColor, _modeColor.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: _modeColor.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ScoreStat(
                      label: 'Score',
                      value: '${session.score}/${session.totalQuestions}',
                      icon: Icons.star_rounded,
                    ),
                    _ScoreStat(
                      label: 'Accuracy',
                      value: '${(pct * 100).round()}%',
                      icon: Icons.track_changes_rounded,
                    ),
                    _ScoreStat(
                      label: 'Best Streak',
                      value: '${session.bestStreak}🔥',
                      icon: Icons.local_fire_department_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // XP Earned
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFF22C55E), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '+$xp XP Earned',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
              ),

              // Accuracy bar
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Accuracy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    pct >= 0.7 ? Colors.green : Colors.orangeAccent,
                  ),
                ),
              ),

              // Missed words section
              if (session.missedWords.isNotEmpty) ...[
                const SizedBox(height: 28),
                const Row(
                  children: [
                    Icon(Icons.replay_rounded, size: 18, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'Review These Words',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...session.missedWords.map((w) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.redAccent,
                            ),
                          ),
                          if (w.summary != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              w.summary!.definition,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )),
              ],

              const SizedBox(height: 32),

              // CTAs
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (_) => QuizModeScreen(mode: mode)),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Play Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _modeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Pop all the way back to mode selector
                    Navigator.of(context).popUntil(
                      (route) => route.isFirst || route.settings.name == '/',
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Choose Another Mode'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _title(double pct) {
    if (pct >= 0.9) return 'Outstanding!';
    if (pct >= 0.7) return 'Well Done!';
    if (pct >= 0.5) return 'Keep Going!';
    return 'Need More Practice';
  }

  String _subtitle(double pct) {
    if (pct >= 0.9) return 'You nailed almost every word!';
    if (pct >= 0.7) return 'Great effort — keep reviewing the tough ones.';
    if (pct >= 0.5) return 'You\'re making progress. Try the review list below.';
    return 'Check the missed words below and try again.';
  }
}

class _ScoreStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ScoreStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: Colors.white70, size: 20),
      const SizedBox(height: 6),
      Text(value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          )),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}

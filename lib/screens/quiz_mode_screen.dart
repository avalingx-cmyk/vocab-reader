import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/quiz_engine.dart';
import '../models/word.dart';
import '../providers/quiz_provider.dart';
import '../theme/app_theme.dart';
import 'quiz_results_screen.dart';

class QuizModeScreen extends ConsumerStatefulWidget {
  final QuizMode mode;
  final List<Word>? dueWords;
  const QuizModeScreen({super.key, required this.mode, this.dueWords});

  @override
  ConsumerState<QuizModeScreen> createState() => _QuizModeScreenState();
}

class _QuizModeScreenState extends ConsumerState<QuizModeScreen> {
  final _shakeKey = GlobalKey<_ShakeWidgetState>();
  String? _selectedAnswer;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(quizProvider.notifier)
          .startSession(mode: widget.mode, dueWords: widget.dueWords);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _submitAnswer(String answer) {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _selectedAnswer = answer;
    });
    final isCorrect = ref.read(quizProvider).session?.currentQuestion
        ?.correctAnswer.toLowerCase() == answer.toLowerCase().trim();
    ref.read(quizProvider.notifier).submitAnswer(answer);
    if (!isCorrect) _shakeKey.currentState?.shake();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final s = ref.read(quizProvider);
      if (s.isComplete) {
        _goToResults(s.session!);
      } else {
        setState(() { _submitted = false; _selectedAnswer = null; });
      }
    });
  }

  void _goToResults(QuizSession session) {
    ref.read(quizProvider.notifier).reset();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => QuizResultsScreen(session: session, mode: widget.mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizProvider);
    final session = quizState.session;

    // Navigate to results once complete (handles flashcard mode)
    ref.listen(quizProvider, (_, next) {
      if (next.isComplete && next.session != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _goToResults(next.session!);
        });
      }
    });

    if (quizState.isGenerating) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_modeTitle(widget.mode)),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Generating quiz...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_modeTitle(widget.mode)), backgroundColor: Colors.transparent),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.auto_stories_rounded, size: 80,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 24),
              Text('No words with AI summaries yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(widget.dueWords != null
                      ? 'You have no due review words right now. Come back later or play a regular mode.'
                      : 'Add some words and let AI analyze them first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ]),
          ),
        ),
      );
    }

    final question = session.currentQuestion;
    if (question == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_modeTitle(widget.mode)),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${session.currentIndex + 1}/${session.totalQuestions}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: session.currentIndex / session.totalQuestions,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(_modeColor(widget.mode)),
            minHeight: 4,
          ),
          // Score & streak strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _StatPill(
                  icon: Icons.star_rounded,
                  label: '${session.score} pts',
                  color: AppTheme.accentAmber,
                ),
                const SizedBox(width: 10),
                if (session.streak > 1)
                  _StatPill(
                    icon: Icons.local_fire_department_rounded,
                    label: '${session.streak}🔥',
                    color: Colors.deepOrange,
                  ),
              ],
            ),
          ),
          if (quizState.generationNotice != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  quizState.generationNotice!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _ShakeWidget(
              key: _shakeKey,
              child: _buildModeContent(context, session, question),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeContent(
      BuildContext context, QuizSession session, QuizQuestion question) {
    switch (widget.mode) {
      case QuizMode.flashcard:
        return _FlashcardMode(question: question, quizState: ref.watch(quizProvider));
      case QuizMode.multipleChoice:
        return _MultipleChoiceMode(
          question: question,
          selectedAnswer: _selectedAnswer,
          submitted: _submitted,
          onAnswer: _submitAnswer,
          color: _modeColor(widget.mode),
        );
    }
  }

  String _modeTitle(QuizMode mode) {
    switch (mode) {
      case QuizMode.flashcard: return 'Flashcards';
      case QuizMode.multipleChoice: return 'Multiple Choice';
    }
  }

  Color _modeColor(QuizMode mode) {
    switch (mode) {
      case QuizMode.flashcard: return AppTheme.primaryBlue;
      case QuizMode.multipleChoice: return const Color(0xFF7C3AED);
    }
  }
}

// ── Flashcard Mode ────────────────────────────────────────────────────────────
class _FlashcardMode extends ConsumerWidget {
  final QuizQuestion question;
  final QuizState quizState;
  const _FlashcardMode({required this.question, required this.quizState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFlipped = quizState.showingAnswer;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(quizProvider.notifier).flipCard(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) {
                  final rotate = Tween(begin: 3.14, end: 0.0).animate(anim);
                  return AnimatedBuilder(
                    animation: rotate,
                    child: child,
                    builder: (_, c) {
                      final isUnder = (ValueKey(isFlipped) != c!.key);
                      final tilt =
                          ((anim.value - 0.5).abs() - 0.5) * 0.003 * (isUnder ? -1.0 : 1.0);
                      final rotVal = isUnder ? rotate.value : rotate.value - 3.14;
                      return Transform(
                        transform: Matrix4.rotationY(rotVal)..setEntry(3, 0, tilt),
                        alignment: Alignment.center,
                        child: c,
                      );
                    },
                  );
                },
                child: isFlipped ? _CardBack(question: question) : _CardFront(question: question),
              ),
            ),
          ),
          if (isFlipped) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Still Learning',
                    icon: Icons.close_rounded,
                    color: Colors.redAccent,
                    onTap: () => ref.read(quizProvider.notifier).submitFlashcard(known: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Got It!',
                    icon: Icons.check_rounded,
                    color: Colors.green,
                    onTap: () => ref.read(quizProvider.notifier).submitFlashcard(known: true),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 20),
            Text(
              'Tap card to reveal definition',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  final QuizQuestion question;
  const _CardFront({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey(false),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.style_rounded, size: 48, color: AppTheme.primaryBlue.withValues(alpha: 0.4)),
            const SizedBox(height: 24),
            Text(
              question.word.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
            if (question.word.bookName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                question.word.bookName,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final QuizQuestion question;
  const _CardBack({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey(true),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryBlue, AppTheme.primaryBlue.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            question.word.summary!.definition,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white, height: 1.5),
          ),
          if (question.word.summary!.useCases.isNotEmpty) ...[
            const Divider(color: Colors.white24, height: 40),
            Text(
              '"${question.word.summary!.useCases.first}"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14, color: Colors.white70, fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ── Multiple Choice Mode ─────────────────────────────────────────────────────
class _MultipleChoiceMode extends StatelessWidget {
  final QuizQuestion question;
  final String? selectedAnswer;
  final bool submitted;
  final void Function(String) onAnswer;
  final Color color;

  const _MultipleChoiceMode({
    required this.question,
    required this.selectedAnswer,
    required this.submitted,
    required this.onAnswer,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word to define
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(children: [
              Text(
                question.questionLabel.isEmpty
                    ? 'What does this word mean?'
                    : question.questionLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                question.questionText.isEmpty
                    ? question.word.text
                    : question.questionText,
                style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: color,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          // Options
          ...question.options.map((opt) => _OptionTile(
                option: opt,
                correctAnswer: question.correctAnswer,
                selectedAnswer: selectedAnswer,
                submitted: submitted,
                color: color,
                onTap: submitted ? null : () => onAnswer(opt),
              )),
          if (submitted && question.explanation != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Why: ${question.explanation!}',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String option;
  final String correctAnswer;
  final String? selectedAnswer;
  final bool submitted;
  final Color color;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.option,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.submitted,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = Theme.of(context).colorScheme.outlineVariant;
    Color bgColor = Theme.of(context).colorScheme.surface;
    Widget? trailing;

    if (submitted) {
      final isCorrect = option == correctAnswer;
      final isSelected = option == selectedAnswer;
      if (isCorrect) {
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.08);
        trailing = const Icon(Icons.check_circle_rounded, color: Colors.green);
      } else if (isSelected) {
        borderColor = Colors.redAccent;
        bgColor = Colors.redAccent.withValues(alpha: 0.08);
        trailing = const Icon(Icons.cancel_rounded, color: Colors.redAccent);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(children: [
          Expanded(
            child: Text(option, style: const TextStyle(fontSize: 15, height: 1.4)),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ]),
      ),
    );
  }
}

// ── Stat Pill ────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}

// ── Shake Widget ──────────────────────────────────────────────────────────────
class _ShakeWidget extends StatefulWidget {
  final Widget child;
  const _ShakeWidget({super.key, required this.child});

  @override
  State<_ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<_ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void shake() {
    _ctrl.forward(from: 0).then((_) => _ctrl.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        final dx = _anim.value * 8 * (_ctrl.status == AnimationStatus.forward ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

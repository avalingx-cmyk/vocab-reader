import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/word.dart';
import '../providers/quiz_provider.dart';
import '../theme/app_theme.dart';
import 'quiz_mode_screen.dart';
import '../game/quiz_engine.dart';
import 'word_detail_screen.dart';

enum ReviewFilter { due, fresh, weak, mastered }
enum ReviewSort { recommended, nearestDue, weakestFirst, newestFirst, strongestFirst, alphabetic }

final reviewFilterProvider = StateProvider<ReviewFilter>((ref) => ReviewFilter.due);
final reviewSortProvider = StateProvider<ReviewSort>((ref) => ReviewSort.recommended);

class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reviewFilterProvider);
    final sort = ref.watch(reviewSortProvider);
    final stats = ref.watch(reviewStatsProvider);
    final dueWords = ref.watch(dueWordsProvider);
    final newWords = ref.watch(newStudyWordsProvider);
    final weakWords = ref.watch(weakWordsProvider);
    final masteredWords = ref.watch(masteredWordsProvider);

    final baseWords = switch (filter) {
      ReviewFilter.due => dueWords,
      ReviewFilter.fresh => newWords,
      ReviewFilter.weak => weakWords,
      ReviewFilter.mastered => masteredWords,
    };
    final words = _sortWords(baseWords, filter, sort);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Practice what matters and build a real learning rhythm.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          _ReviewHeroCard(stats: stats),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ReviewFilterChip(
                label: 'Due',
                count: dueWords.length,
                selected: filter == ReviewFilter.due,
                onTap: () => ref.read(reviewFilterProvider.notifier).state = ReviewFilter.due,
              ),
              _ReviewFilterChip(
                label: 'New',
                count: newWords.length,
                selected: filter == ReviewFilter.fresh,
                onTap: () => ref.read(reviewFilterProvider.notifier).state = ReviewFilter.fresh,
              ),
              _ReviewFilterChip(
                label: 'Weak',
                count: weakWords.length,
                selected: filter == ReviewFilter.weak,
                onTap: () => ref.read(reviewFilterProvider.notifier).state = ReviewFilter.weak,
              ),
              _ReviewFilterChip(
                label: 'Mastered',
                count: masteredWords.length,
                selected: filter == ReviewFilter.mastered,
                onTap: () => ref.read(reviewFilterProvider.notifier).state = ReviewFilter.mastered,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ReviewSortBar(
            filter: filter,
            selected: sort,
            onChanged: (value) => ref.read(reviewSortProvider.notifier).state = value,
          ),
          const SizedBox(height: 18),
          if (words.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => QuizModeScreen(
                      mode: filter == ReviewFilter.weak
                          ? QuizMode.multipleChoice
                          : QuizMode.flashcard,
                      dueWords: words,
                    ),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Start ${_titleForFilter(filter)} Review'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            '${_titleForFilter(filter)} Words',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (words.isEmpty)
            _EmptyReviewState(filter: filter)
          else
            ...words.map((word) => _ReviewWordTile(word: word, filter: filter)),
        ],
      ),
    );
  }

  String _titleForFilter(ReviewFilter filter) {
    return switch (filter) {
      ReviewFilter.due => 'Due',
      ReviewFilter.fresh => 'New',
      ReviewFilter.weak => 'Weak',
      ReviewFilter.mastered => 'Mastered',
    };
  }

  List<Word> _sortWords(
    List<Word> source,
    ReviewFilter filter,
    ReviewSort sort,
  ) {
    final words = [...source];
    int byText(Word a, Word b) => a.text.toLowerCase().compareTo(b.text.toLowerCase());

    switch (sort) {
      case ReviewSort.alphabetic:
        words.sort(byText);
        break;
      case ReviewSort.newestFirst:
        words.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case ReviewSort.nearestDue:
        words.sort((a, b) {
          final ad = a.nextReviewAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = b.nextReviewAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return ad.compareTo(bd);
        });
        break;
      case ReviewSort.weakestFirst:
        words.sort((a, b) {
          final af = a.failureCount - a.successCount;
          final bf = b.failureCount - b.successCount;
          final cmp = bf.compareTo(af);
          return cmp != 0 ? cmp : byText(a, b);
        });
        break;
      case ReviewSort.strongestFirst:
        words.sort((a, b) {
          final cmp = b.successCount.compareTo(a.successCount);
          return cmp != 0 ? cmp : byText(a, b);
        });
        break;
      case ReviewSort.recommended:
        switch (filter) {
          case ReviewFilter.due:
            words.sort((a, b) {
              final ad = a.nextReviewAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bd = b.nextReviewAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return ad.compareTo(bd);
            });
            break;
          case ReviewFilter.fresh:
            words.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case ReviewFilter.weak:
            words.sort((a, b) {
              final af = a.failureCount - a.successCount;
              final bf = b.failureCount - b.successCount;
              final cmp = bf.compareTo(af);
              return cmp != 0 ? cmp : byText(a, b);
            });
            break;
          case ReviewFilter.mastered:
            words.sort((a, b) {
              final cmp = b.successCount.compareTo(a.successCount);
              return cmp != 0 ? cmp : byText(a, b);
            });
            break;
        }
        break;
    }

    return words;
  }
}

class _ReviewSortBar extends StatelessWidget {
  final ReviewFilter filter;
  final ReviewSort selected;
  final ValueChanged<ReviewSort> onChanged;

  const _ReviewSortBar({
    required this.filter,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = _optionsForFilter(filter);
    return Row(
      children: [
        Icon(Icons.sort_rounded,
            size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          'Sort',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options
                  .map((option) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_label(option)),
                          selected: selected == option,
                          onSelected: (_) => onChanged(option),
                          selectedColor:
                              AppTheme.primaryBlue.withValues(alpha: 0.14),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected == option
                                ? AppTheme.primaryBlue
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          side: BorderSide(
                            color: selected == option
                                ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                                : Theme.of(context).dividerColor,
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  List<ReviewSort> _optionsForFilter(ReviewFilter filter) {
    return switch (filter) {
      ReviewFilter.due => [ReviewSort.recommended, ReviewSort.nearestDue, ReviewSort.alphabetic],
      ReviewFilter.fresh => [ReviewSort.recommended, ReviewSort.newestFirst, ReviewSort.alphabetic],
      ReviewFilter.weak => [ReviewSort.recommended, ReviewSort.weakestFirst, ReviewSort.alphabetic],
      ReviewFilter.mastered => [ReviewSort.recommended, ReviewSort.strongestFirst, ReviewSort.alphabetic],
    };
  }

  String _label(ReviewSort sort) {
    return switch (sort) {
      ReviewSort.recommended => 'Recommended',
      ReviewSort.nearestDue => 'Nearest due',
      ReviewSort.weakestFirst => 'Weakest first',
      ReviewSort.newestFirst => 'Newest first',
      ReviewSort.strongestFirst => 'Strongest first',
      ReviewSort.alphabetic => 'A-Z',
    };
  }
}

class _ReviewHeroCard extends StatelessWidget {
  final ReviewStats stats;
  const _ReviewHeroCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F766E),
            const Color(0xFF14B8A6).withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330F766E),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.military_tech_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.badgeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${stats.streakDays} day streak · ${(stats.accuracy * 100).toInt()}% accuracy',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _heroMetric('Due', stats.dueCount.toString())),
              Expanded(child: _heroMetric('Weak', stats.weakCount.toString())),
              Expanded(child: _heroMetric('Mastered', stats.masteredCount.toString())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82), fontSize: 12)),
      ],
    );
  }
}

class _ReviewFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _ReviewFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected
            ? AppTheme.primaryBlue
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      side: BorderSide(
        color: selected
            ? AppTheme.primaryBlue.withValues(alpha: 0.35)
            : Theme.of(context).dividerColor,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _ReviewWordTile extends StatelessWidget {
  final Word word;
  final ReviewFilter filter;

  const _ReviewWordTile({required this.word, required this.filter});

  @override
  Widget build(BuildContext context) {
    final nextReview = word.nextReviewAt;
    String subtitle;
    if (filter == ReviewFilter.mastered) {
      subtitle = 'Mastered · ${word.successCount} correct answers';
    } else if (filter == ReviewFilter.weak) {
      subtitle = 'Needs reinforcement · ${word.failureCount} misses';
    } else if (nextReview != null) {
      subtitle = 'Next review: ${nextReview.day}/${nextReview.month}';
    } else {
      subtitle = 'Ready for first review';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        title: Text(word.text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              word.summary?.definition ?? 'No definition yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WordDetailScreen(word: word)),
        ),
      ),
    );
  }
}

class _EmptyReviewState extends StatelessWidget {
  final ReviewFilter filter;
  const _EmptyReviewState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      ReviewFilter.due => 'No words are due right now.',
      ReviewFilter.fresh => 'No freshly learned words yet.',
      ReviewFilter.weak => 'No weak words. Nice work.',
      ReviewFilter.mastered => 'No mastered words yet.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

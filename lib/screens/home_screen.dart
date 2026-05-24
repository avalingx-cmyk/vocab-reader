import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/sync_service.dart';
import 'add_word_screen.dart';
import 'word_detail_screen.dart';
import 'books_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../models/user_level.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);
final _debounceTimerProvider = StateProvider<Timer?>((ref) => null);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trySync());

    _syncSubscription = SyncService.instance.syncStatusStream.listen((status) {
      if (status == SyncStatus.error) {
        if (mounted) {
          final reason = SyncService.instance.lastError;
          final errMsg = SyncService.instance.lastErrorMessage;
          String msg;
          switch (reason) {
            case SyncError.notConfigured:
              msg = 'AI not configured. Add an API key in Settings.';
              break;
            case SyncError.localLibUnavailable:
              msg =
                  'Local AI engine missing in this build. Please use Gemini or OpenAI in Settings.';
              break;
            case SyncError.localModelMissing:
              msg =
                  'Local AI model not downloaded. Go to Settings to download it.';
              break;
            case SyncError.networkError:
              msg = 'Network error. Please check your internet connection.';
              break;
            case SyncError.localAiFailed:
              msg = errMsg ??
                  'Local AI generation failed for some words. Check logs.';
              break;
            case SyncError.unknown:
            default:
              msg =
                  'Sync failed. Check your API key or model download in Settings.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      if (status == SyncStatus.completed || status == SyncStatus.error) {
        if (mounted) {
          ref.invalidate(wordListProvider(null));
          ref.invalidate(filteredWordsProvider(null));
        }
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _trySync() async {
    if (SyncService.instance.isSyncing) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Checking for words to sync...'),
          duration: Duration(seconds: 1)),
    );
    await SyncService.instance.resetFailedWords();
    if (mounted) ref.invalidate(wordListProvider(null));
  }

  void _onSearchChanged(String value) {
    final timer = ref.read(_debounceTimerProvider);
    timer?.cancel();
    final newTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(wordSearchProvider.notifier).state = value;
    });
    ref.read(_debounceTimerProvider.notifier).state = newTimer;
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(wordSearchProvider.notifier).state = '';
    setState(() => _isSearchExpanded = false);
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);

    ref.listen(connectivityProvider, (previous, next) {
      if (previous?.value != true && next.value == true) {
        _trySync();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentIndex == 0 ? 'My Library' : 'Bookshelf',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          if (currentIndex == 0) ...[
            _ConnectivityBadge(),
            _SyncButton(onSyncPressed: _trySync),
            IconButton(
              icon:
                  Icon(_isSearchExpanded ? Icons.close : Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearchExpanded = !_isSearchExpanded;
                  if (_isSearchExpanded) {
                    _searchFocusNode.requestFocus();
                  } else {
                    _clearSearch();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ],
        bottom: currentIndex == 0 && _isSearchExpanded
            ? PreferredSize(
                preferredSize: const Size.fromHeight(72),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search your vocabulary...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppTheme.primaryBlue),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryBlue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 0),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: IndexedStack(
          index: currentIndex,
          children: const [
            WordsTab(),
            BooksScreen(),
            QuizScreen(),
          ],
        ),
      ),
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddWordScreen()),
                );
                if (mounted) {
                  ref.invalidate(wordListProvider(null));
                  _trySync();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Word'),
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => ref.read(navIndexProvider.notifier).state = i,
          showUnselectedLabels: false,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.style_rounded), // Cards icon for words
              activeIcon: Icon(Icons.style_rounded),
              label: 'Vocabulary',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book_rounded),
              activeIcon: Icon(Icons.book_rounded),
              label: 'Books',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.quiz_outlined),
              activeIcon: Icon(Icons.quiz_rounded),
              label: 'Quiz',
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectivityBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = ref.watch(connectivityProvider);
    final isOnline = conn.value ?? true;
    if (isOnline) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.wifi_off_rounded,
          size: 18, color: AppTheme.accentAmber),
    );
  }
}

class _SyncButton extends StatelessWidget {
  final VoidCallback onSyncPressed;
  const _SyncButton({required this.onSyncPressed});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncService.instance.syncStatusStream,
      builder: (context, snapshot) {
        final syncing = snapshot.data == SyncStatus.syncing ||
            SyncService.instance.isSyncing;
        if (syncing) {
          return StreamBuilder<SyncProgress>(
            stream: SyncService.instance.syncProgressStream,
            builder: (context, progressSnapshot) {
              final progress = progressSnapshot.data;
              final label = progress != null && progress.total > 0
                  ? '${progress.processed}/${progress.total}'
                  : '';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryBlue),
                    ),
                    if (label.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryBlue)),
                    ],
                  ],
                ),
              );
            },
          );
        }
        return IconButton(
          icon: const Icon(Icons.sync_rounded),
          onPressed: onSyncPressed,
        );
      },
    );
  }
}

class WordsTab extends ConsumerWidget {
  const WordsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(filteredWordsProvider(null));
    final searchQuery = ref.watch(wordSearchProvider);

    return wordsAsync.when(
      data: (words) {
        if (words.isEmpty) {
          return searchQuery.isNotEmpty
              ? _buildNoResults(context, searchQuery)
              : _buildEmptyState(context);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: words.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              final booksCount = words.map((w) => w.bookName).toSet().length;
              return _DashboardHeader(
                  wordsCount: words.length, booksCount: booksCount);
            }
            return _WordCard(word: words[index - 1]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories_rounded,
                size: 100,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            Text('Your Library is Empty',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              'Add words you discover while reading to build your personal lexicon.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddWordScreen()),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Your First Word'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(BuildContext context, String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text('No Results Found',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('We couldn\'t find anything matching "$query"',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _DashboardHeader extends ConsumerWidget {
  final int wordsCount;
  final int booksCount;

  const _DashboardHeader({required this.wordsCount, required this.booksCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final int weeklyGoal = settings.weeklyGoal;
    // Calculate new words this week - for demo we use a portion of total
    final int newThisWeek = (wordsCount > (weeklyGoal * 0.8).toInt())
        ? (weeklyGoal * 0.8).toInt()
        : wordsCount;
    final double progress = (weeklyGoal > 0) ? newThisWeek / weeklyGoal : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, Avaling!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildExpandableCart(
                context,
                'Word Learn Cart',
                wordsCount.toString(),
                Icons.style_rounded,
                AppTheme.primaryBlue,
                'Click to see all words',
                () => ref.read(navIndexProvider.notifier).state =
                    0, // Stay here but highlight list
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildExpandableCart(
                context,
                'Book Track Cart',
                booksCount.toString(),
                Icons.book_rounded,
                AppTheme.accentAmber,
                'Click to manage books',
                () => ref.read(navIndexProvider.notifier).state =
                    1, // Go to books tab
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildMomentumCard(context, newThisWeek, weeklyGoal, progress),
        const SizedBox(height: 32),
        Text(
          'Recent Words',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildExpandableCart(BuildContext context, String title, String value,
      IconData icon, Color color, String submenuText, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text(
                        submenuText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded, size: 14, color: color),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMomentumCard(
      BuildContext context, int current, int goal, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withValues(alpha: 0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Keep the momentum!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "You've learned $current new words this week. Reach your goal of $goal to unlock the 'Polyglot' badge.",
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                height: 1.4),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% of weekly goal reached',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final Word word;
  const _WordCard({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WordDetailScreen(word: word)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      word.text,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (word.isPending)
                      _PendingChip()
                    else
                      _LevelBadge(level: word.userLevel),
                  ],
                ),
                const SizedBox(height: 12),
                if (word.summary != null)
                  Text(
                    word.summary!.definition,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.4),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.bookmark_outline_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      word.bookName,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    if (word.pageNumber != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.tag_rounded,
                          size: 14,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Page ${word.pageNumber}',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  final UserLevel level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level.displayName,
        style: const TextStyle(
          color: AppTheme.primaryBlue,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PendingChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 12, color: AppTheme.accentAmber),
          SizedBox(width: 4),
          Text(
            'Analyzing',
            style: TextStyle(
                fontSize: 11,
                color: AppTheme.accentAmber,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

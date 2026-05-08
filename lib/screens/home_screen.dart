import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/sync_service.dart';
import 'add_word_screen.dart';
import 'word_detail_screen.dart';
import 'books_screen.dart';
import 'settings_screen.dart';

/// Provider for current bottom nav tab index
final navIndexProvider = StateProvider<int>((ref) => 0);

/// Provider to debounce search input
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

  @override
  void initState() {
    super.initState();
    _trySync();
  }

  Future<void> _trySync() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (isConnected && !SyncService.instance.isSyncing) {
        await SyncService.instance.processPendingQueue();
      }
    } on SocketException catch (_) {
      // Offline, don't sync
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
    setState(() {
      _isSearchExpanded = false;
    });
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: currentIndex == 0 ? const Text('VocabReader') : const Text('Books'),
        actions: [
          if (currentIndex == 0) ...[
            IconButton(
              icon: const Icon(Icons.search),
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
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ],
        ],
        bottom: currentIndex == 0
            ? PreferredSize(
                preferredSize: Size.fromHeight(_isSearchExpanded ? 64 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: _isSearchExpanded ? 64 : 0,
                  child: _isSearchExpanded
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search words, books, definitions...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref.read(wordSearchProvider.notifier).state = '';
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                        )
                      : null,
                ),
              )
            : null,
      ),
      body: IndexedStack(
        index: currentIndex,
        children: const [
          WordsTab(),
          BooksScreen(),
        ],
      ),
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddWordScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Word'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(navIndexProvider.notifier).state = index;
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Words',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: 'Books',
          ),
        ],
      ),
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
          if (searchQuery.isNotEmpty) {
            return _buildNoResults(context, searchQuery);
          }
          return _buildEmptyState(context);
        }
        return _buildWordList(context, words);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No words yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Start building your vocabulary by adding words from your books',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddWordScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Your First Word'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(BuildContext context, String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'No words matching "$query"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(BuildContext context, List<Word> words) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        return _buildWordCard(context, word);
      },
    );
  }

  Widget _buildWordCard(BuildContext context, Word word) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                word.text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            if (word.isPending)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pending,
                      size: 14,
                      color: Colors.orange[800],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '${word.bookName}${word.pageNumber != null ? ' • Page ${word.pageNumber}' : ''}',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            if (word.summary != null) ...[
              const SizedBox(height: 8),
              Text(
                word.summary!.definition,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(word.userLevel.displayName),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WordDetailScreen(word: word),
            ),
          );
        },
      ),
    );
  }
}

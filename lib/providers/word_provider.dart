import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../services/database_service.dart';

/// Provider for the current search query
final wordSearchProvider = StateProvider<String>((ref) => '');

/// Provider that fetches all words, optionally filtered by book name
final wordListProvider = FutureProvider.family<List<Word>, String?>((ref, bookName) async {
  return await DatabaseService.instance.getWords(bookName: bookName);
});

/// Provider that fetches pending words
final pendingWordsProvider = FutureProvider<List<Word>>((ref) async {
  return await DatabaseService.instance.getWords(isPending: true);
});

/// Provider that fetches a single word by ID
final wordProvider = FutureProvider.family<Word?, String>((ref, wordId) async {
  return await DatabaseService.instance.getWord(wordId);
});

/// Provider that combines word list with search query for real-time filtering
final filteredWordsProvider = FutureProvider.family<List<Word>, String?>((ref, bookName) async {
  final wordsAsync = ref.watch(wordListProvider(bookName));
  final searchQuery = ref.watch(wordSearchProvider);

  return wordsAsync.when(
    data: (words) {
      if (searchQuery.isEmpty) {
        return words;
      }
      final query = searchQuery.toLowerCase();
      return words.where((word) {
        return word.text.toLowerCase().contains(query) ||
            word.bookName.toLowerCase().contains(query) ||
            (word.summary?.definition.toLowerCase().contains(query) ?? false);
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Notifier to trigger refreshes of word providers
final wordRefreshProvider = StateNotifierProvider<WordRefreshNotifier, int>((ref) {
  return WordRefreshNotifier();
});

class WordRefreshNotifier extends StateNotifier<int> {
  WordRefreshNotifier() : super(0);

  void refresh() => state++;
}

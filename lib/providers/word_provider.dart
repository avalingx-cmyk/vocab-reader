import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../services/database_service.dart';

final wordSearchProvider = StateProvider<String>((ref) => '');

final wordListProvider =
    FutureProvider.family<List<Word>, String?>((ref, bookId) async {
  ref.watch(wordRefreshProvider);
  final data = await DatabaseService.instance.getWords(bookId: bookId);
  ref.read(_wordListCacheProvider(bookId).notifier).state = data;
  return data;
});

final _wordListCacheProvider =
    StateProvider.family<List<Word>, String?>((ref, bookId) => []);

final filteredWordsProvider =
    Provider.family<List<Word>, String?>((ref, bookId) {
  final wordsAsync = ref.watch(wordListProvider(bookId));
  final searchQuery = ref.watch(wordSearchProvider);

  final words = wordsAsync.valueOrNull ??
      ref.watch(_wordListCacheProvider(bookId)) ??
      [];
  if (searchQuery.isEmpty) return words;

  final query = searchQuery.toLowerCase();
  return words.where((word) {
    return word.text.toLowerCase().contains(query) ||
        word.bookName.toLowerCase().contains(query) ||
        (word.summary?.definition.toLowerCase().contains(query) ?? false);
  }).toList();
});

final wordRefreshProvider =
    StateNotifierProvider<WordRefreshNotifier, int>((ref) {
  return WordRefreshNotifier();
});

final wordsNeedingSummaryProvider = Provider<List<Word>>((ref) {
  final wordsAsync = ref.watch(wordListProvider(null));
  final words = wordsAsync.value ?? [];
  return words.where((word) => word.summary == null).toList();
});

final failedSummaryWordsProvider = Provider<List<Word>>((ref) {
  final words = ref.watch(wordsNeedingSummaryProvider);
  return words.where((word) => !word.isPending).toList();
});

class WordRefreshNotifier extends StateNotifier<int> {
  WordRefreshNotifier() : super(0);
  void refresh() => state++;
}

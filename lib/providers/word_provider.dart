import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../services/database_service.dart';

final wordSearchProvider = StateProvider<String>((ref) => '');

final wordListProvider =
    FutureProvider.family<List<Word>, String?>((ref, bookName) async {
  ref.watch(wordRefreshProvider);
  final data = await DatabaseService.instance.getWords(bookName: bookName);
  ref.read(_wordListCacheProvider(bookName).notifier).state = data;
  return data;
});

final _wordListCacheProvider =
    StateProvider.family<List<Word>, String?>((ref, bookName) => []);

final filteredWordsProvider =
    Provider.family<List<Word>, String?>((ref, bookName) {
  final wordsAsync = ref.watch(wordListProvider(bookName));
  final searchQuery = ref.watch(wordSearchProvider);

  final words = wordsAsync.valueOrNull ??
      ref.watch(_wordListCacheProvider(bookName)) ??
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

class WordRefreshNotifier extends StateNotifier<int> {
  WordRefreshNotifier() : super(0);
  void refresh() => state++;
}

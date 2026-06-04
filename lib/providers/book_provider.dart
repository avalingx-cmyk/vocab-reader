import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../services/database_service.dart';
import 'word_provider.dart';

/// Provider that fetches all unique book names from the database
final bookListProvider = FutureProvider<List<BookInfo>>((ref) async {
  ref.watch(wordRefreshProvider);
  final books = await DatabaseService.instance.getBooks();
  final words = await DatabaseService.instance.getWords();
  final pendingByBook = <String, int>{};
  for (final word in words) {
    if (word.bookId == null || !word.isPending) continue;
    pendingByBook[word.bookId!] = (pendingByBook[word.bookId!] ?? 0) + 1;
  }

  return books
      .map((book) => BookInfo(
            id: book.id,
            name: book.name,
            wordCount: book.wordCount,
            pendingCount: pendingByBook[book.id] ?? 0,
            lastAccessed: book.lastAccessed,
          ))
      .toList();
});

/// Provider that fetches words for a specific book
final bookWordsProvider = FutureProvider.family<List<Word>, String>((ref, bookId) async {
  return await DatabaseService.instance.getWords(bookId: bookId);
});

/// Model for book information
class BookInfo {
  final String id;
  final String name;
  final int wordCount;
  final int pendingCount;
  final DateTime lastAccessed;

  BookInfo({
    required this.id,
    required this.name,
    required this.wordCount,
    required this.pendingCount,
    required this.lastAccessed,
  });

  bool get isAllComplete => pendingCount == 0;
  double get progress => wordCount > 0 ? (wordCount - pendingCount) / wordCount : 0.0;
}

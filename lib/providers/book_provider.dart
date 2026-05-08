import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/word.dart';
import '../services/database_service.dart';

/// Provider that fetches all unique book names from the database
final bookListProvider = FutureProvider<List<BookInfo>>((ref) async {
  final words = await DatabaseService.instance.getWords();

  // Group words by book name
  final bookMap = <String, List<Word>>{};
  for (final word in words) {
    bookMap.putIfAbsent(word.bookName, () => []);
    bookMap[word.bookName]!.add(word);
  }

  // Create book info list
  final books = bookMap.entries.map((entry) {
    final bookWords = entry.value;
    final pendingCount = bookWords.where((w) => w.isPending).length;
    final lastAccessed = bookWords
        .map((w) => w.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return BookInfo(
      name: entry.key,
      wordCount: bookWords.length,
      pendingCount: pendingCount,
      lastAccessed: lastAccessed,
    );
  }).toList();

  // Sort by last accessed descending
  books.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));

  return books;
});

/// Provider that fetches words for a specific book
final bookWordsProvider = FutureProvider.family<List<Word>, String>((ref, bookName) async {
  return await DatabaseService.instance.getWords(bookName: bookName);
});

/// Model for book information
class BookInfo {
  final String name;
  final int wordCount;
  final int pendingCount;
  final DateTime lastAccessed;

  BookInfo({
    required this.name,
    required this.wordCount,
    required this.pendingCount,
    required this.lastAccessed,
  });

  bool get isAllComplete => pendingCount == 0;
  double get progress => wordCount > 0 ? (wordCount - pendingCount) / wordCount : 0.0;
}

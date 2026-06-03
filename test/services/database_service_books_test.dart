import 'dart:io';

import 'package:bookbeam/models/user_level.dart';
import 'package:bookbeam/models/word.dart';
import 'package:bookbeam/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseService.resetForTesting();
  });

  test('fresh database assigns real book ids to new words', () async {
    final dbPath = _tempDbPath('fresh_books.db');
    await DatabaseService.resetForTesting(
      databasePath: dbPath,
      deleteExisting: false,
    );
    await DatabaseService.instance.init();

    final saved = await DatabaseService.instance.addWord(
      Word(
        id: 'word-1',
        text: 'ephemeral',
        bookName: 'Meditations',
        userLevel: UserLevel.beginner,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    final books = await DatabaseService.instance.getBooks();
    final words = await DatabaseService.instance.getWords(bookId: saved.bookId);

    expect(saved.bookId, isNotNull);
    expect(books, hasLength(1));
    expect(books.single.name, 'Meditations');
    expect(words.single.bookId, books.single.id);
  });

  test('upgrade from legacy rows backfills book ids and preserves names', () async {
    final dbPath = _tempDbPath('legacy_books.db');
    await DatabaseService.resetForTesting(
      databasePath: dbPath,
      deleteExisting: false,
    );
    await DatabaseService.instance.init();
    final db = await DatabaseService.instance.database;
    await db.insert('words', {
      'id': 'legacy-1',
      'text': 'ephemeral',
      'book_id': null,
      'book_name': 'Meditations',
      'user_level': 'beginner',
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
      'updated_at': DateTime(2026, 1, 1).toIso8601String(),
    });
    await db.insert('words', {
      'id': 'legacy-2',
      'text': 'meticulous',
      'book_id': null,
      'book_name': 'Dune',
      'user_level': 'intermediate',
      'created_at': DateTime(2026, 1, 2).toIso8601String(),
      'updated_at': DateTime(2026, 1, 2).toIso8601String(),
    });

    await DatabaseService.resetForTesting(
      databasePath: dbPath,
      deleteExisting: false,
    );
    await DatabaseService.instance.init();

    final words = await DatabaseService.instance.getWords();
    final books = await DatabaseService.instance.getBooks();

    expect(words, hasLength(2));
    expect(words.every((word) => word.bookId != null && word.bookId!.isNotEmpty), isTrue);
    expect(books.map((book) => book.name), containsAll(['Meditations', 'Dune']));
  });

  test('renaming into an existing book merges linked words safely', () async {
    final dbPath = _tempDbPath('rename_merge.db');
    await DatabaseService.resetForTesting(databasePath: dbPath);
    await DatabaseService.instance.init();

    final first = await DatabaseService.instance.addWord(
      Word(
        id: 'word-1',
        text: 'ephemeral',
        bookName: 'Meditations',
        userLevel: UserLevel.beginner,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    await DatabaseService.instance.addWord(
      Word(
        id: 'word-2',
        text: 'meticulous',
        bookName: 'Dune',
        userLevel: UserLevel.beginner,
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
      ),
    );

    final booksBefore = await DatabaseService.instance.getBooks();
    final meditations = booksBefore.firstWhere((book) => book.name == 'Meditations');
    await DatabaseService.instance.renameBook(meditations.id, 'Dune');

    final booksAfter = await DatabaseService.instance.getBooks();
    final dune = booksAfter.singleWhere((book) => book.name == 'Dune');
    final duneWords = await DatabaseService.instance.getWords(bookId: dune.id);

    expect(booksAfter.where((book) => book.name == 'Dune'), hasLength(1));
    expect(duneWords.map((word) => word.id), containsAll([first.id, 'word-2']));
  });
}

String _tempDbPath(String filename) {
  final directory = Directory.systemTemp.createTempSync('bookbeam_test_');
  return p.join(directory.path, filename);
}

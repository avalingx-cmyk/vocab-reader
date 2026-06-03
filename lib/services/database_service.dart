import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/word.dart';
import '../models/user_level.dart';

class DatabaseService {
  static Database? _database;
  static String? _databasePathOverride;
  static final DatabaseService instance = DatabaseService._init();

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vocab_reader.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final path = _databasePathOverride ?? join(await getDatabasesPath(), filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE words ADD COLUMN last_reviewed_at TEXT
      ''');
      await db.execute('''
        ALTER TABLE words ADD COLUMN next_review_at TEXT
      ''');
      await db.execute('''
        ALTER TABLE words ADD COLUMN success_count INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE words ADD COLUMN failure_count INTEGER DEFAULT 0
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS books (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          author TEXT,
          word_count INTEGER DEFAULT 0,
          last_accessed TEXT
        )
      ''');
      await db.execute('''
        ALTER TABLE words ADD COLUMN book_id TEXT
      ''');
      await _createBookIndexes(db);
      await _backfillBooks(db);
    }
    if (oldVersion < 4) {
      await _createLaunchSupportTables(db);
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        author TEXT,
        word_count INTEGER DEFAULT 0,
        last_accessed TEXT
      )
    ''');
    await _createBookIndexes(db);

    await db.execute('''
      CREATE TABLE words (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        book_id TEXT,
        book_name TEXT NOT NULL,
        page_number INTEGER,
        context TEXT,
        user_level TEXT NOT NULL,
        definition TEXT,
        main_say TEXT,
        use_cases TEXT,
        similar_words TEXT,
        detailed_summary TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_pending INTEGER DEFAULT 0,
        last_reviewed_at TEXT,
        next_review_at TEXT,
        success_count INTEGER DEFAULT 0,
        failure_count INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_queue (
        word_id TEXT PRIMARY KEY,
        queued_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        FOREIGN KEY (word_id) REFERENCES words(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await _createLaunchSupportTables(db);
  }

  Future<void> init() async {
    final db = await database;
    await _repairBookLinks(db);
  }

  @visibleForTesting
  static Future<void> resetForTesting({
    String? databasePath,
    bool deleteExisting = true,
  }) async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    _databasePathOverride = databasePath;
    if (databasePath != null && deleteExisting) {
      final file = File(databasePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  // Word operations
  Future<Word> addWord(Word word) async {
    final db = await database;
    final saved = await _ensureWordBook(word);
    await db.insert('words', _wordToMap(saved));
    await _refreshBookStats(saved.bookId!);
    return saved;
  }

  Future<Word> updateWord(Word word) async {
    final db = await database;
    final existing = await getWord(word.id);
    final saved = await _ensureWordBook(word);
    await db.update(
      'words',
      _wordToMap(saved),
      where: 'id = ?',
      whereArgs: [saved.id],
    );
    await _refreshBookStats(saved.bookId!);
    if (existing?.bookId != null && existing!.bookId != saved.bookId) {
      await _refreshBookStats(existing.bookId!);
    }
    return saved;
  }

  Future<void> deleteWord(String id) async {
    final db = await database;
    final existing = await getWord(id);
    await db.delete(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (existing?.bookId != null) {
      await _refreshBookStats(existing!.bookId!);
    }
  }

  Future<Word?> getWord(String id) async {
    final db = await database;
    final maps = await db.rawQuery(
      '''
      SELECT w.*, COALESCE(b.name, w.book_name) AS hydrated_book_name
      FROM words w
      LEFT JOIN books b ON b.id = w.book_id
      WHERE w.id = ?
      LIMIT 1
      ''',
      [id],
    );

    if (maps.isNotEmpty) {
      return _mapToWord(maps.first);
    }
    return null;
  }

  Future<List<Word>> getWords({
    String? bookId,
    String? bookName,
    String? search,
    bool? isPending,
  }) async {
    final db = await database;

    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    if (bookId != null) {
      whereParts.add('w.book_id = ?');
      whereArgs.add(bookId);
    } else if (bookName != null) {
      whereParts.add('b.name = ?');
      whereArgs.add(bookName);
    }

    if (search != null && search.isNotEmpty) {
      whereParts.add('w.text LIKE ?');
      whereArgs.add('%$search%');
    }

    if (isPending != null) {
      whereParts.add('w.is_pending = ?');
      whereArgs.add(isPending ? 1 : 0);
    }

    final maps = await db.rawQuery(
      '''
      SELECT w.*, COALESCE(b.name, w.book_name) AS hydrated_book_name
      FROM words w
      LEFT JOIN books b ON b.id = w.book_id
      ${whereParts.isEmpty ? '' : 'WHERE ${whereParts.join(' AND ')}'}
      ORDER BY w.created_at DESC
      ''',
      whereArgs,
    );

    return maps.map((map) => _mapToWord(map)).toList();
  }

  Future<BookRecord> upsertBook(String name, {String? author}) async {
    final db = await database;
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Book name cannot be empty');
    }
    final existing = await db.query(
      'books',
      where: 'lower(name) = lower(?)',
      whereArgs: [cleanName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final book = BookRecord.fromMap(existing.first);
      await _refreshBookStats(book.id);
      return book;
    }

    final id = const Uuid().v4();
    final now = DateTime.now().toIso8601String();
    final map = {
      'id': id,
      'name': cleanName,
      'author': author,
      'word_count': 0,
      'last_accessed': now,
    };
    await db.insert('books', map);
    return BookRecord.fromMap(map);
  }

  Future<List<BookRecord>> getBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: 'last_accessed DESC');
    return maps.map(BookRecord.fromMap).toList();
  }

  Future<void> renameBook(String id, String name) async {
    final db = await database;
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Book name cannot be empty');
    }

    final duplicate = await db.query(
      'books',
      where: 'lower(name) = lower(?) AND id != ?',
      whereArgs: [cleanName, id],
      limit: 1,
    );

    if (duplicate.isNotEmpty) {
      final targetId = duplicate.first['id'] as String;
      await db.transaction((txn) async {
        await txn.update(
          'words',
          {'book_id': targetId, 'book_name': cleanName},
          where: 'book_id = ?',
          whereArgs: [id],
        );
        await txn.delete('books', where: 'id = ?', whereArgs: [id]);
      });
      await _refreshBookStats(targetId);
      return;
    }

    await db.transaction((txn) async {
      await txn.update(
        'books',
        {
          'name': cleanName,
          'last_accessed': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'words',
        {'book_name': cleanName},
        where: 'book_id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteBookAndWords(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final words = await txn.query(
        'words',
        columns: ['id'],
        where: 'book_id = ?',
        whereArgs: [id],
      );
      for (final word in words) {
        await txn.delete(
          'pending_queue',
          where: 'word_id = ?',
          whereArgs: [word['id']],
        );
      }
      await txn.delete('words', where: 'book_id = ?', whereArgs: [id]);
      await txn.delete('books', where: 'id = ?', whereArgs: [id]);
    });
  }

  // Pending queue operations
  Future<void> addToQueue(String wordId) async {
    final db = await database;
    // INSERT OR REPLACE resets retry_count to 0 if word was already in queue
    // (handles re-queuing after previous failures / max retries)
    await db.insert(
      'pending_queue',
      {
        'word_id': wordId,
        'queued_at': DateTime.now().toIso8601String(),
        'retry_count': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFromQueue(String wordId) async {
    final db = await database;
    await db.delete(
      'pending_queue',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final db = await database;
    return await db.query('pending_queue', orderBy: 'queued_at ASC');
  }

  Future<int> countWordsNeedingSummary() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM words WHERE definition IS NULL OR definition = ""',
        )) ??
        0;
  }

  Future<int> countFailedSummaryWords() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery(
          '''
          SELECT COUNT(*)
          FROM words
          WHERE (definition IS NULL OR definition = '')
            AND is_pending = 0
          ''',
        )) ??
        0;
  }

  // Settings operations
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }

  Future<void> insertAnalyticsEvent({
    required String name,
    String? payloadJson,
  }) async {
    final db = await database;
    await db.insert('analytics_events', {
      'id': const Uuid().v4(),
      'name': name,
      'payload_json': payloadJson,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAnalyticsEvents({int limit = 100}) async {
    final db = await database;
    return db.query(
      'analytics_events',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> insertErrorLog({
    required String scope,
    required String message,
    String? details,
    String? stackTrace,
  }) async {
    final db = await database;
    await db.insert('error_logs', {
      'id': const Uuid().v4(),
      'scope': scope,
      'message': message,
      'details': details,
      'stack_trace': stackTrace,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getErrorLogs({int limit = 50}) async {
    final db = await database;
    return db.query(
      'error_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  // Helper methods
  Map<String, dynamic> _wordToMap(Word word) {
    return {
      'id': word.id,
      'text': word.text,
      'book_id': word.bookId,
      'book_name': word.bookName,
      'page_number': word.pageNumber,
      'context': word.context,
      'user_level': word.userLevel.name,
      'definition': word.summary?.definition,
      'main_say': word.summary?.mainSay,
      'use_cases': word.summary?.useCases.join('|||'),
      'similar_words': word.summary?.similarWords.join('|||'),
      'detailed_summary': word.summary?.detailedSummary,
      'created_at': word.createdAt.toIso8601String(),
      'updated_at': word.updatedAt.toIso8601String(),
      'is_pending': word.isPending ? 1 : 0,
      'last_reviewed_at': word.lastReviewedAt?.toIso8601String(),
      'next_review_at': word.nextReviewAt?.toIso8601String(),
      'success_count': word.successCount,
      'failure_count': word.failureCount,
    };
  }

  Word _mapToWord(Map<String, dynamic> map) {
    WordSummary? summary;
    if (map['definition'] != null) {
      summary = WordSummary(
        definition: map['definition'] as String,
        mainSay: map['main_say'] as String,
        useCases: (map['use_cases'] as String?)?.split('|||') ?? [],
        similarWords: (map['similar_words'] as String?)?.split('|||') ?? [],
        detailedSummary: map['detailed_summary'] as String,
        generatedAt: DateTime.now(),
      );
    }

    return Word(
      id: map['id'] as String,
      text: map['text'] as String,
      bookId: map['book_id'] as String?,
      bookName: (map['hydrated_book_name'] ?? map['book_name']) as String,
      pageNumber: map['page_number'] as int?,
      context: map['context'] as String?,
      userLevel: UserLevel.fromString(map['user_level'] as String),
      summary: summary,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isPending: (map['is_pending'] as int) == 1,
      lastReviewedAt: map['last_reviewed_at'] != null
          ? DateTime.parse(map['last_reviewed_at'] as String)
          : null,
      nextReviewAt: map['next_review_at'] != null
          ? DateTime.parse(map['next_review_at'] as String)
          : null,
      successCount: map['success_count'] as int? ?? 0,
      failureCount: map['failure_count'] as int? ?? 0,
    );
  }

  Future<void> clearLegacyAiSettings() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final key in const [
        'ai_provider',
        'openai_key',
        'gemini_key',
        'weekly_goal',
      ]) {
        await txn.delete('settings', where: 'key = ?', whereArgs: [key]);
      }
    });
  }

  Future<void> _createBookIndexes(Database db) async {
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_books_name_lower ON books(lower(name))');
  }

  Future<void> _createLaunchSupportTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS analytics_events (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        payload_json TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS error_logs (
        id TEXT PRIMARY KEY,
        scope TEXT NOT NULL,
        message TEXT NOT NULL,
        details TEXT,
        stack_trace TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _backfillBooks(Database db) async {
    final words = await db.query('words', columns: ['book_name']);
    final names = words
        .map((row) => (row['book_name'] as String?)?.trim())
        .whereType<String>()
        .where((name) => name.isNotEmpty)
        .toSet();

    for (final name in names) {
      final existing = await db.query(
        'books',
        where: 'lower(name) = lower(?)',
        whereArgs: [name],
        limit: 1,
      );
      final bookId = existing.isNotEmpty
          ? existing.first['id'] as String
          : const Uuid().v4();
      if (existing.isEmpty) {
        await db.insert('books', {
          'id': bookId,
          'name': name,
          'author': null,
          'word_count': 0,
          'last_accessed': DateTime.now().toIso8601String(),
        });
      }
      await db.update(
        'words',
        {'book_id': bookId},
        where: 'book_id IS NULL AND lower(book_name) = lower(?)',
        whereArgs: [name],
      );
      await _refreshBookStatsWithDb(db, bookId);
    }
  }

  Future<void> _repairBookLinks(Database db) async {
    await _backfillBooks(db);
  }

  Future<Word> _ensureWordBook(Word word) async {
    if (word.bookId != null && word.bookId!.isNotEmpty) {
      return word;
    }
    final book = await upsertBook(word.bookName);
    return word.copyWith(bookId: book.id, bookName: book.name);
  }

  Future<void> _refreshBookStats(String bookId) async {
    final db = await database;
    await _refreshBookStatsWithDb(db, bookId);
  }

  Future<void> _refreshBookStatsWithDb(Database db, String bookId) async {
    final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM words WHERE book_id = ?',
          [bookId],
        )) ??
        0;
    final last = await db.rawQuery(
      'SELECT MAX(updated_at) AS last_accessed FROM words WHERE book_id = ?',
      [bookId],
    );
    await db.update(
      'books',
      {
        'word_count': count,
        'last_accessed': (last.first['last_accessed'] as String?) ??
            DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }
}

class BookRecord {
  final String id;
  final String name;
  final String? author;
  final int wordCount;
  final DateTime lastAccessed;

  const BookRecord({
    required this.id,
    required this.name,
    this.author,
    required this.wordCount,
    required this.lastAccessed,
  });

  factory BookRecord.fromMap(Map<String, Object?> map) {
    return BookRecord(
      id: map['id'] as String,
      name: map['name'] as String,
      author: map['author'] as String?,
      wordCount: map['word_count'] as int? ?? 0,
      lastAccessed: map['last_accessed'] != null
          ? DateTime.parse(map['last_accessed'] as String)
          : DateTime.now(),
    );
  }
}

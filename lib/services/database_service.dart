import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/word.dart';
import '../models/user_level.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._init();

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vocab_reader.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
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
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
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
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        author TEXT,
        word_count INTEGER DEFAULT 0,
        last_accessed TEXT
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
  }

  Future<void> init() async {
    await database;
  }

  // Word operations
  Future<Word> addWord(Word word) async {
    final db = await database;
    await db.insert('words', _wordToMap(word));
    return word;
  }

  Future<Word> updateWord(Word word) async {
    final db = await database;
    await db.update(
      'words',
      _wordToMap(word),
      where: 'id = ?',
      whereArgs: [word.id],
    );
    return word;
  }

  Future<void> deleteWord(String id) async {
    final db = await database;
    await db.delete(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Word?> getWord(String id) async {
    final db = await database;
    final maps = await db.query(
      'words',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _mapToWord(maps.first);
    }
    return null;
  }

  Future<List<Word>> getWords({
    String? bookName,
    String? search,
    bool? isPending,
  }) async {
    final db = await database;
    
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (bookName != null) {
      whereClause = 'book_name = ?';
      whereArgs = [bookName];
    }
    
    if (search != null && search.isNotEmpty) {
      whereClause = whereClause != null 
          ? '$whereClause AND text LIKE ?'
          : 'text LIKE ?';
      whereArgs ??= [];
      whereArgs.add('%$search%');
    }
    
    if (isPending != null) {
      whereClause = whereClause != null
          ? '$whereClause AND is_pending = ?'
          : 'is_pending = ?';
      whereArgs ??= [];
      whereArgs.add(isPending ? 1 : 0);
    }

    final maps = await db.query(
      'words',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => _mapToWord(map)).toList();
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

  // Helper methods
  Map<String, dynamic> _wordToMap(Word word) {
    return {
      'id': word.id,
      'text': word.text,
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
      bookName: map['book_name'] as String,
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
}

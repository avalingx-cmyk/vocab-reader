import 'dart:io';

import 'package:bookbeam/services/analytics_service.dart';
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

  test('stores analytics events locally for later inspection', () async {
    final dbPath = _tempDbPath('analytics.db');
    await DatabaseService.resetForTesting(
      databasePath: dbPath,
      deleteExisting: false,
    );
    await DatabaseService.instance.init();

    await LocalAnalyticsService.instance.track(
      'word.added',
      payload: {'bookId': 'book-1', 'hasContext': true},
    );
    await LocalAnalyticsService.instance.track(
      'summary.generated',
      payload: {'wordId': 'word-1'},
    );

    final events = await LocalAnalyticsService.instance.recentEvents(limit: 10);

    expect(events, hasLength(2));
    expect(events.first.name, 'summary.generated');
    expect(events.last.name, 'word.added');
    expect(events.last.payload['bookId'], 'book-1');
  });

  test('records recoverable errors into local storage', () async {
    final dbPath = _tempDbPath('error_events.db');
    await DatabaseService.resetForTesting(
      databasePath: dbPath,
      deleteExisting: false,
    );
    await DatabaseService.instance.init();

    await LocalAnalyticsService.instance.recordError(
      scope: 'sync.process_pending_queue',
      error: 'model unavailable',
      details: {'retryCount': 3},
    );

    final errors = await DatabaseService.instance.getErrorLogs(limit: 5);
    final events = await LocalAnalyticsService.instance.recentEvents(limit: 5);

    expect(errors, hasLength(1));
    expect(errors.single['scope'], 'sync.process_pending_queue');
    expect(events.first.name, 'error.recorded');
  });
}

String _tempDbPath(String filename) {
  final directory = Directory.systemTemp.createTempSync('bookbeam_analytics_');
  return p.join(directory.path, filename);
}

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_service.dart';

class AnalyticsEvent {
  final String id;
  final String name;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  const AnalyticsEvent({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.payload,
  });
}

abstract class AnalyticsService {
  Future<void> track(
    String name, {
    Map<String, dynamic> payload = const {},
  });

  Future<void> recordError({
    required String scope,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic> details = const {},
  });

  Future<List<AnalyticsEvent>> recentEvents({int limit = 100});
}

class LocalAnalyticsService implements AnalyticsService {
  LocalAnalyticsService._();

  static final LocalAnalyticsService instance = LocalAnalyticsService._();

  @override
  Future<void> track(
    String name, {
    Map<String, dynamic> payload = const {},
  }) async {
    await DatabaseService.instance.insertAnalyticsEvent(
      name: name,
      payloadJson: payload.isEmpty ? null : jsonEncode(payload),
    );
  }

  @override
  Future<void> recordError({
    required String scope,
    required Object error,
    StackTrace? stackTrace,
    Map<String, dynamic> details = const {},
  }) async {
    await DatabaseService.instance.insertErrorLog(
      scope: scope,
      message: error.toString(),
      details: details.isEmpty ? null : jsonEncode(details),
      stackTrace: stackTrace?.toString(),
    );

    await track(
      'error.recorded',
      payload: {
        'scope': scope,
        'message': error.toString(),
      },
    );
  }

  @override
  Future<List<AnalyticsEvent>> recentEvents({int limit = 100}) async {
    final rows = await DatabaseService.instance.getAnalyticsEvents(limit: limit);
    return rows
        .map(
          (row) => AnalyticsEvent(
            id: row['id'] as String,
            name: row['name'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            payload: (row['payload_json'] as String?) == null
                ? const {}
                : Map<String, dynamic>.from(
                    jsonDecode(row['payload_json'] as String) as Map,
                  ),
          ),
        )
        .toList();
  }
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return LocalAnalyticsService.instance;
});

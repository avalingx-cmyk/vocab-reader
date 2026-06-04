import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';

final recentAnalyticsEventsProvider =
    FutureProvider<List<AnalyticsEvent>>((ref) async {
  return ref.read(analyticsServiceProvider).recentEvents(limit: 8);
});

final recentErrorLogsProvider = FutureProvider<List<ErrorLogEntry>>((ref) async {
  return ref.read(analyticsServiceProvider).recentErrors(limit: 5);
});

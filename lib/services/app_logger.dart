import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void info(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

/// StreamProvider that emits `true`/`false` based on real internet reachability.
/// Starts with `AsyncLoading` until first check completes.
final connectivityProvider = StreamProvider<bool>((ref) {
  final checker = ConnectivityChecker.instance;
  checker.startChecking();
  return checker.connectivityStream;
});

// ─── ConnectivityChecker (singleton) ─────────────────────────────────────────

class ConnectivityChecker {
  static final ConnectivityChecker instance = ConnectivityChecker._internal();
  factory ConnectivityChecker() => instance;
  ConnectivityChecker._internal();

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Timer? _timer;
  bool? _lastState; // null = unknown yet

  Stream<bool> get connectivityStream => _controller.stream;

  /// The most recently known connectivity state (defaults to true if unknown).
  bool get isConnected => _lastState ?? true;

  void startChecking() {
    if (_timer != null) return; // already running
    _checkNow(); // immediate first check
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkNow());
  }

  void stopChecking() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkNow() async {
    final result = await _reachable();
    if (result != _lastState) {
      _lastState = result;
      if (!_controller.isClosed) _controller.add(result);
    }
  }

  Future<bool> _reachable() async {
    // Try Google, then Cloudflare as fallback
    for (final host in ['google.com', 'one.one.one.one']) {
      try {
        final result = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 4));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // continue to next host
      }
    }
    return false;
  }

  void dispose() {
    stopChecking();
    _controller.close();
  }
}

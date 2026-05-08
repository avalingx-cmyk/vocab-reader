import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for connectivity state
final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityChecker().connectivityStream;
});

/// Provider for the current connectivity state (synchronous access)
final isConnectedProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(connectivityProvider);
});

class ConnectivityChecker {
  static final ConnectivityChecker _instance = ConnectivityChecker._internal();
  factory ConnectivityChecker() => _instance;
  ConnectivityChecker._internal();

  final _connectivityController = StreamController<bool>.broadcast();
  Timer? _checkTimer;
  bool _lastState = true;

  Stream<bool> get connectivityStream => _connectivityController.stream;

  void startChecking() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnectivity());
    _checkConnectivity(); // Initial check
  }

  void stopChecking() {
    _checkTimer?.cancel();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (isConnected != _lastState) {
        _lastState = isConnected;
        _connectivityController.add(isConnected);
      }
    } on SocketException catch (_) {
      if (_lastState != false) {
        _lastState = false;
        _connectivityController.add(false);
      }
    } catch (_) {
      if (_lastState != false) {
        _lastState = false;
        _connectivityController.add(false);
      }
    }
  }

  void dispose() {
    _checkTimer?.cancel();
    _connectivityController.close();
  }
}

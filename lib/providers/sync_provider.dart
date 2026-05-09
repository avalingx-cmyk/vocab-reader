import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for sync state
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier();
});

/// Provider for sync progress percentage
final syncProgressProvider = Provider<double>((ref) {
  final syncState = ref.watch(syncProvider);
  if (syncState.total == 0) return 0.0;
  return syncState.processed / syncState.total;
});

/// Provider to check if there are any pending items to sync
final hasPendingSyncProvider = Provider<bool>((ref) {
  final syncState = ref.watch(syncProvider);
  return syncState.total > 0;
});

enum SyncStatus { idle, syncing, error, completed }

class SyncState {
  final SyncStatus status;
  final int processed;
  final int total;
  final String? errorMessage;
  final DateTime? lastSyncTime;

  const SyncState({
    this.status = SyncStatus.idle,
    this.processed = 0,
    this.total = 0,
    this.errorMessage,
    this.lastSyncTime,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? processed,
    int? total,
    String? errorMessage,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      status: status ?? this.status,
      processed: processed ?? this.processed,
      total: total ?? this.total,
      errorMessage: errorMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  bool get isIdle => status == SyncStatus.idle;
  bool get isSyncing => status == SyncStatus.syncing;
  bool get isError => status == SyncStatus.error;
  bool get isCompleted => status == SyncStatus.completed;
  double get progress => total > 0 ? processed / total : 0.0;
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(const SyncState());

  void startSync({required int total}) {
    state = SyncState(
      status: SyncStatus.syncing,
      processed: 0,
      total: total,
    );
  }

  void updateProgress(int processed) {
    state = state.copyWith(processed: processed);
  }

  void completeSync() {
    state = SyncState(
      status: SyncStatus.completed,
      processed: state.total,
      total: state.total,
      lastSyncTime: DateTime.now(),
    );

    // Reset to idle after a short delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        state = SyncState(
          status: SyncStatus.idle,
          lastSyncTime: state.lastSyncTime,
        );
      }
    });
  }

  void setError(String message) {
    state = SyncState(
      status: SyncStatus.error,
      processed: state.processed,
      total: state.total,
      errorMessage: message,
    );
  }

  void reset() {
    state = const SyncState();
  }
}

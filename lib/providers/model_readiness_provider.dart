import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';
import '../services/cactus_local_service.dart';
import 'settings_provider.dart';

final cactusLocalServiceProvider = Provider<CactusLocalService>((ref) {
  return CactusLocalService();
});

enum ModelReadinessStatus {
  checking,
  unsupported,
  notDownloaded,
  downloading,
  ready,
  repairNeeded,
}

class ModelReadinessState {
  final ModelReadinessStatus status;
  final double progress;
  final String title;
  final String message;
  final String ctaLabel;
  final bool isBusy;

  const ModelReadinessState({
    this.status = ModelReadinessStatus.checking,
    this.progress = 0,
    this.title = 'Checking local AI',
    this.message = 'Verifying offline AI availability.',
    this.ctaLabel = 'Open Settings',
    this.isBusy = false,
  });

  bool get canDownload => status == ModelReadinessStatus.notDownloaded;
  bool get canRepair => status == ModelReadinessStatus.repairNeeded;
  bool get isReady => status == ModelReadinessStatus.ready;

  ModelReadinessState copyWith({
    ModelReadinessStatus? status,
    double? progress,
    String? title,
    String? message,
    String? ctaLabel,
    bool? isBusy,
  }) {
    return ModelReadinessState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      title: title ?? this.title,
      message: message ?? this.message,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

final modelReadinessProvider =
    StateNotifierProvider<ModelReadinessNotifier, ModelReadinessState>((ref) {
  final notifier = ModelReadinessNotifier(ref);
  ref.listen<SettingsState>(settingsProvider, (_, __) {
    notifier.refresh();
  });
  return notifier;
});

class ModelReadinessNotifier extends StateNotifier<ModelReadinessState> {
  ModelReadinessNotifier(this._ref) : super(const ModelReadinessState()) {
    refresh();
  }

  final Ref _ref;
  CancelToken? _cancelToken;

  CactusLocalService get _service => _ref.read(cactusLocalServiceProvider);
  AnalyticsService get _analytics => _ref.read(analyticsServiceProvider);

  Future<void> refresh() async {
    final modelId = _ref.read(settingsProvider).cactusModelId;
    state = state.copyWith(
      status: ModelReadinessStatus.checking,
      title: 'Checking local AI',
      message: 'Verifying offline AI availability.',
      ctaLabel: 'Open Settings',
      isBusy: false,
      progress: 0,
    );

    if (!_service.isNativeLibraryAvailable) {
      state = const ModelReadinessState(
        status: ModelReadinessStatus.unsupported,
        title: 'Offline AI is unavailable here',
        message:
            'This build supports local AI on Android. Your words still save locally.',
        ctaLabel: 'Android Required',
      );
      return;
    }

    final downloaded = await _service.isModelDownloaded(modelId);
    if (downloaded) {
      state = const ModelReadinessState(
        status: ModelReadinessStatus.ready,
        title: 'Offline AI is ready',
        message: 'New words can be summarized on this device.',
        ctaLabel: 'Repair Model',
      );
    } else {
      state = const ModelReadinessState(
        status: ModelReadinessStatus.notDownloaded,
        title: 'Download offline AI',
        message:
            'Download the local model before BookBeam can create word explanations.',
        ctaLabel: 'Download Model',
      );
    }
  }

  Future<void> download() async {
    final modelId = _ref.read(settingsProvider).cactusModelId;
    final config = _service.getModelConfig(modelId);
    _cancelToken = CancelToken();
    state = state.copyWith(
      status: ModelReadinessStatus.downloading,
      title: 'Downloading offline AI',
      message: 'Preparing ${config.displayName} for offline vocabulary help.',
      ctaLabel: 'Cancel Download',
      isBusy: true,
      progress: 0,
    );
    await _analytics.track(
      'model.download_started',
      payload: {'modelId': modelId},
    );

    final result = await _service.downloadModel(
      modelId,
      (count, total) {
        state = state.copyWith(
          progress: total == 0 ? 0 : count / total,
          message: 'Downloading ${config.displayName} '
              '(${((total == 0 ? 0 : count / total) * 100).toStringAsFixed(0)}%)',
        );
      },
      cancelToken: _cancelToken,
    );

    if (result.isSuccess) {
      await _analytics.track(
        'model.download_completed',
        payload: {'modelId': modelId},
      );
      await refresh();
      return;
    }

    if (result.message == 'Download cancelled') {
      await _analytics.track(
        'model.download_cancelled',
        payload: {'modelId': modelId},
      );
      state = const ModelReadinessState(
        status: ModelReadinessStatus.notDownloaded,
        title: 'Download cancelled',
        message: 'Offline AI was not downloaded yet.',
        ctaLabel: 'Download Model',
      );
      return;
    }

    await _analytics.track(
      'model.download_failed',
      payload: {'modelId': modelId, 'message': result.message ?? 'unknown'},
    );
    await _analytics.recordError(
      scope: 'model.download',
      error: result.message ?? 'Download failed',
    );
    state = ModelReadinessState(
      status: ModelReadinessStatus.repairNeeded,
      title: 'Download failed',
      message: result.message ??
          'The offline AI download failed. Check your connection and try again.',
      ctaLabel: 'Try Again',
    );
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  Future<void> repair() async {
    final modelId = _ref.read(settingsProvider).cactusModelId;
    state = state.copyWith(
      status: ModelReadinessStatus.repairNeeded,
      title: 'Repairing offline AI',
      message: 'Removing the old model so you can download a fresh copy.',
      ctaLabel: 'Download Model',
      isBusy: true,
      progress: 0,
    );
    await _service.deleteModel(modelId);
    await _analytics.track(
      'model.repair_requested',
      payload: {'modelId': modelId},
    );
    await refresh();
  }

  void markGenerationFailure(String? message) {
    state = ModelReadinessState(
      status: ModelReadinessStatus.repairNeeded,
      title: 'Offline AI needs attention',
      message: message ??
          'BookBeam could not generate a summary. Repair or re-download the model.',
      ctaLabel: 'Repair Model',
    );
  }
}

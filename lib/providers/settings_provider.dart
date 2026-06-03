import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_level.dart';
import '../services/analytics_service.dart';
import '../services/cactus_local_service.dart';
import '../services/database_service.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsState {
  final UserLevel userLevel;
  final String cactusModelId;
  final bool isLoading;

  const SettingsState({
    this.userLevel = UserLevel.beginner,
    this.cactusModelId = CactusLocalService.defaultModelId,
    this.isLoading = true,
  });

  SettingsState copyWith({
    UserLevel? userLevel,
    String? cactusModelId,
    bool? isLoading,
  }) {
    return SettingsState(
      userLevel: userLevel ?? this.userLevel,
      cactusModelId: cactusModelId ?? this.cactusModelId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier({bool loadFromStorage = true}) : super(const SettingsState()) {
    if (loadFromStorage) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final levelStr = await DatabaseService.instance.getSetting('user_level');
    final cactusModel =
        await DatabaseService.instance.getSetting('cactus_model_id');
    final validCactusIds =
        CactusLocalService.availableModels.map((m) => m.id).toSet();
    const fallbackCactusModel = CactusLocalService.defaultModelId;
    final safeCactusModel =
        cactusModel != null && validCactusIds.contains(cactusModel)
            ? cactusModel
            : fallbackCactusModel;

    state = SettingsState(
      userLevel: UserLevel.fromString(levelStr ?? UserLevel.beginner.name),
      cactusModelId: safeCactusModel,
      isLoading: false,
    );

    if (safeCactusModel != cactusModel) {
      await DatabaseService.instance.setSetting(
        'cactus_model_id',
        safeCactusModel,
      );
    }
    await DatabaseService.instance.clearLegacyAiSettings();
  }

  Future<void> setUserLevel(UserLevel level) async {
    await DatabaseService.instance.setSetting('user_level', level.name);
    state = state.copyWith(userLevel: level);
    await LocalAnalyticsService.instance.track(
      'learner_level.updated',
      payload: {'learnerLevel': level.name},
    );
  }

  Future<void> setCactusModelId(String modelId) async {
    await DatabaseService.instance.setSetting('cactus_model_id', modelId);
    state = state.copyWith(cactusModelId: modelId);
  }
}

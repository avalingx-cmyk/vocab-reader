import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_level.dart';
import '../services/cactus_local_service.dart';
import '../services/database_service.dart';
import '../services/local_ai_service.dart';

/// Provider for app settings
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsState {
  final UserLevel userLevel;
  final String aiProvider;
  final String localModelId;
  final String cactusModelId;
  final String? openAIKey;
  final String? geminiKey;
  final int weeklyGoal;
  final bool isLoading;

  const SettingsState({
    this.userLevel = UserLevel.beginner,
    this.aiProvider = 'openai',
    this.localModelId = 'qwen',
    this.cactusModelId = 'gemma-270m',
    this.openAIKey,
    this.geminiKey,
    this.weeklyGoal = 20,
    this.isLoading = true,
  });

  SettingsState copyWith({
    UserLevel? userLevel,
    String? aiProvider,
    String? localModelId,
    String? cactusModelId,
    String? openAIKey,
    String? geminiKey,
    int? weeklyGoal,
    bool? isLoading,
  }) {
    return SettingsState(
      userLevel: userLevel ?? this.userLevel,
      aiProvider: aiProvider ?? this.aiProvider,
      localModelId: localModelId ?? this.localModelId,
      cactusModelId: cactusModelId ?? this.cactusModelId,
      openAIKey: openAIKey ?? this.openAIKey,
      geminiKey: geminiKey ?? this.geminiKey,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      isLoading: isLoading ?? this.isLoading,
    );
  }


  bool get hasAIKey {
    if (aiProvider == 'openai') {
      return openAIKey != null && openAIKey!.isNotEmpty;
    } else {
      return geminiKey != null && geminiKey!.isNotEmpty;
    }
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final levelStr = await DatabaseService.instance.getSetting('user_level');
    final provider = await DatabaseService.instance.getSetting('ai_provider');
    final localModel = await DatabaseService.instance.getSetting('local_model_id');
    final cactusModel = await DatabaseService.instance.getSetting('cactus_model_id');
    final openAIKey = await DatabaseService.instance.getSetting('openai_key');
    final geminiKey = await DatabaseService.instance.getSetting('gemini_key');
    final weeklyGoalStr = await DatabaseService.instance.getSetting('weekly_goal');

    final validLocalIds =
        LocalAIService.availableModels.map((m) => m.id).toSet();
    final safeLocalModel =
        localModel != null && validLocalIds.contains(localModel)
            ? localModel
            : 'qwen';

    final validCactusIds =
        CactusLocalService.availableModels.map((m) => m.id).toSet();
    final safeCactusModel =
        cactusModel != null && validCactusIds.contains(cactusModel)
            ? cactusModel
            : 'gemma-270m';

    state = SettingsState(
      userLevel: levelStr != null ? UserLevel.fromString(levelStr) : UserLevel.beginner,
      aiProvider: provider ?? 'openai',
      localModelId: safeLocalModel,
      cactusModelId: safeCactusModel,
      openAIKey: openAIKey,
      geminiKey: geminiKey,
      weeklyGoal: weeklyGoalStr != null ? int.tryParse(weeklyGoalStr) ?? 20 : 20,
      isLoading: false,
    );

    if (safeLocalModel != localModel) {
      await DatabaseService.instance.setSetting('local_model_id', safeLocalModel);
    }
    if (safeCactusModel != cactusModel) {
      await DatabaseService.instance.setSetting('cactus_model_id', safeCactusModel);
    }
  }

  Future<void> setUserLevel(UserLevel level) async {
    await DatabaseService.instance.setSetting('user_level', level.name);
    state = state.copyWith(userLevel: level);
  }

  Future<void> setAIProvider(String provider) async {
    await DatabaseService.instance.setSetting('ai_provider', provider);
    state = state.copyWith(aiProvider: provider);
  }

  Future<void> setLocalModelId(String modelId) async {
    await DatabaseService.instance.setSetting('local_model_id', modelId);
    state = state.copyWith(localModelId: modelId);
  }

  Future<void> setCactusModelId(String modelId) async {
    await DatabaseService.instance.setSetting('cactus_model_id', modelId);
    state = state.copyWith(cactusModelId: modelId);
  }

  Future<void> setOpenAIKey(String key) async {
    await DatabaseService.instance.setSetting('openai_key', key);
    state = state.copyWith(openAIKey: key);
  }

  Future<void> setGeminiKey(String key) async {
    await DatabaseService.instance.setSetting('gemini_key', key);
    state = state.copyWith(geminiKey: key);
  }

  Future<void> setWeeklyGoal(int goal) async {
    await DatabaseService.instance.setSetting('weekly_goal', goal.toString());
    state = state.copyWith(weeklyGoal: goal);
  }

  Future<void> saveSettings({
    UserLevel? userLevel,
    String? aiProvider,
    String? openAIKey,
    String? geminiKey,
  }) async {
    if (userLevel != null) await setUserLevel(userLevel);
    if (aiProvider != null) await setAIProvider(aiProvider);
    if (openAIKey != null) await setOpenAIKey(openAIKey);
    if (geminiKey != null) await setGeminiKey(geminiKey);
  }
}

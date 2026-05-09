import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_level.dart';
import '../services/database_service.dart';

/// Provider for app settings
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsState {
  final UserLevel userLevel;
  final String aiProvider;
  final String? openAIKey;
  final String? geminiKey;
  final int weeklyGoal;
  final bool isLoading;

  const SettingsState({
    this.userLevel = UserLevel.beginner,
    this.aiProvider = 'openai',
    this.openAIKey,
    this.geminiKey,
    this.weeklyGoal = 20,
    this.isLoading = true,
  });

  SettingsState copyWith({
    UserLevel? userLevel,
    String? aiProvider,
    String? openAIKey,
    String? geminiKey,
    int? weeklyGoal,
    bool? isLoading,
  }) {
    return SettingsState(
      userLevel: userLevel ?? this.userLevel,
      aiProvider: aiProvider ?? this.aiProvider,
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
    final openAIKey = await DatabaseService.instance.getSetting('openai_key');
    final geminiKey = await DatabaseService.instance.getSetting('gemini_key');
    final weeklyGoalStr = await DatabaseService.instance.getSetting('weekly_goal');

    state = SettingsState(
      userLevel: levelStr != null ? UserLevel.fromString(levelStr) : UserLevel.beginner,
      aiProvider: provider ?? 'openai',
      openAIKey: openAIKey,
      geminiKey: geminiKey,
      weeklyGoal: weeklyGoalStr != null ? int.tryParse(weeklyGoalStr) ?? 20 : 20,
      isLoading: false,
    );
  }

  Future<void> setUserLevel(UserLevel level) async {
    await DatabaseService.instance.setSetting('user_level', level.name);
    state = state.copyWith(userLevel: level);
  }

  Future<void> setAIProvider(String provider) async {
    await DatabaseService.instance.setSetting('ai_provider', provider);
    state = state.copyWith(aiProvider: provider);
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/sync_service.dart';
import '../models/user_level.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    if (settings.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const _SettingsContent();
  }
}

class _SettingsContent extends ConsumerStatefulWidget {
  const _SettingsContent();

  @override
  ConsumerState<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<_SettingsContent> {
  final _openAIKeyController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _openAIKeyController.text = settings.openAIKey ?? '';
    _geminiKeyController.text = settings.geminiKey ?? '';
  }

  @override
  void dispose() {
    _openAIKeyController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.saveSettings(
      openAIKey: _openAIKeyController.text.trim(),
      geminiKey: _geminiKeyController.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved'), backgroundColor: AppTheme.primaryBlue),
    );

    final isOnline = ConnectivityChecker.instance.isConnected;
    if (isOnline && !SyncService.instance.isSyncing) {
      SyncService.instance.processPendingQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Preferences'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('APPEARANCE'),
          const SizedBox(height: 12),
          _buildCard(
            child: Consumer(
              builder: (context, ref, child) {
                final currentTheme = ref.watch(themeModeProvider);
                return Column(
                  children: ThemeMode.values.map((mode) => _buildThemeTile(mode, currentTheme)).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('WEEKLY LEARNING GOAL'),
          const SizedBox(height: 12),
          _buildCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Goal: ${settings.weeklyGoal} words',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Icon(Icons.flag_rounded, color: AppTheme.primaryBlue),
                  ],
                ),
                Slider(
                  value: settings.weeklyGoal.toDouble(),
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: settings.weeklyGoal.toString(),
                  activeColor: AppTheme.primaryBlue,
                  onChanged: (value) {
                    ref.read(settingsProvider.notifier).setWeeklyGoal(value.round());
                  },
                ),
                Text(
                  'Aim for a consistent target to build your vocabulary habit.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('YOUR LEVEL'),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              children: UserLevel.values.map((level) => _buildLevelTile(level, settings.userLevel)).toList(),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('AI PROVIDER'),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              children: [
                _buildProviderTile('Google Gemini', 'gemini-1.5-flash', 'gemini', settings.aiProvider),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildProviderTile('OpenAI', 'GPT-3.5 Turbo', 'openai', settings.aiProvider),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('API KEYS'),
          const SizedBox(height: 12),
          _buildCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildKeyField(
                  controller: _geminiKeyController,
                  label: 'Gemini API Key',
                  hint: 'aistudio.google.com',
                ),
                const SizedBox(height: 20),
                _buildKeyField(
                  controller: _openAIKeyController,
                  label: 'OpenAI API Key',
                  hint: 'sk-...',
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update Keys'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildThemeTile(ThemeMode mode, ThemeMode current) {
    String title;
    switch (mode) {
      case ThemeMode.system: title = 'System Default'; break;
      case ThemeMode.light: title = 'Light'; break;
      case ThemeMode.dark: title = 'Dark'; break;
    }

    return RadioListTile<ThemeMode>(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      value: mode,
      groupValue: current,
      activeColor: AppTheme.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onChanged: (v) {
        if (v != null) ref.read(themeModeProvider.notifier).setTheme(v);
      },
    );
  }

  Widget _buildLevelTile(UserLevel level, UserLevel current) {
    final isSelected = level == current;
    return RadioListTile<UserLevel>(
      title: Text(level.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(level.description, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      value: level,
      groupValue: current,
      activeColor: AppTheme.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onChanged: (v) {
        if (v != null) ref.read(settingsProvider.notifier).setUserLevel(v);
      },
    );
  }

  Widget _buildProviderTile(String name, String sub, String value, String current) {
    return RadioListTile<String>(
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(sub, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      value: value,
      groupValue: current,
      activeColor: AppTheme.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onChanged: (v) {
        if (v != null) ref.read(settingsProvider.notifier).setAIProvider(v);
      },
    );
  }

  Widget _buildKeyField({required TextEditingController controller, required String label, required String hint}) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20, color: AppTheme.primaryBlue),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

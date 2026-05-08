import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../models/user_level.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    if (settings.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    if (settings.openAIKey != null) {
      _openAIKeyController.text = settings.openAIKey!;
    }
    if (settings.geminiKey != null) {
      _geminiKeyController.text = settings.geminiKey!;
    }
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
      openAIKey: _openAIKeyController.text,
      geminiKey: _geminiKeyController.text,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, 'Your Level'),
          ...UserLevel.values.map((level) => RadioListTile<UserLevel>(
            title: Text(level.displayName),
            subtitle: Text(level.description),
            value: level,
            groupValue: settings.userLevel,
            onChanged: (value) {
              if (value != null) {
                ref.read(settingsProvider.notifier).setUserLevel(value);
              }
            },
          )),
          const Divider(height: 32),
          _buildSectionTitle(context, 'AI Provider'),
          RadioListTile<String>(
            title: const Text('OpenAI'),
            subtitle: const Text('GPT-3.5 Turbo'),
            value: 'openai',
            groupValue: settings.aiProvider,
            onChanged: (value) {
              if (value != null) {
                ref.read(settingsProvider.notifier).setAIProvider(value);
              }
            },
          ),
          RadioListTile<String>(
            title: const Text('Google Gemini'),
            subtitle: const Text('Gemini Pro'),
            value: 'gemini',
            groupValue: settings.aiProvider,
            onChanged: (value) {
              if (value != null) {
                ref.read(settingsProvider.notifier).setAIProvider(value);
              }
            },
          ),
          const Divider(height: 32),
          _buildSectionTitle(context, 'API Keys'),
          TextField(
            controller: _openAIKeyController,
            decoration: const InputDecoration(
              labelText: 'OpenAI API Key',
              hintText: 'sk-...',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _geminiKeyController,
            decoration: const InputDecoration(
              labelText: 'Gemini API Key',
              hintText: 'Your Gemini API key',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

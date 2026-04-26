import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/user_level.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserLevel _currentLevel = UserLevel.beginner;
  final _openAIKeyController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  String _selectedProvider = 'openai';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final level = await DatabaseService.instance.getSetting('user_level');
    final provider = await DatabaseService.instance.getSetting('ai_provider');
    final openAIKey = await DatabaseService.instance.getSetting('openai_key');
    final geminiKey = await DatabaseService.instance.getSetting('gemini_key');

    setState(() {
      if (level != null) {
        _currentLevel = UserLevel.fromString(level);
      }
      if (provider != null) {
        _selectedProvider = provider;
      }
      if (openAIKey != null) {
        _openAIKeyController.text = openAIKey;
      }
      if (geminiKey != null) {
        _geminiKeyController.text = geminiKey;
      }
    });
  }

  @override
  void dispose() {
    _openAIKeyController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await DatabaseService.instance.setSetting('user_level', _currentLevel.name);
    await DatabaseService.instance.setSetting('ai_provider', _selectedProvider);
    await DatabaseService.instance.setSetting('openai_key', _openAIKeyController.text);
    await DatabaseService.instance.setSetting('gemini_key', _geminiKeyController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            groupValue: _currentLevel,
            onChanged: (value) {
              setState(() {
                _currentLevel = value!;
              });
            },
          )),
          const Divider(height: 32),
          _buildSectionTitle(context, 'AI Provider'),
          RadioListTile<String>(
            title: const Text('OpenAI'),
            subtitle: const Text('GPT-3.5 Turbo'),
            value: 'openai',
            groupValue: _selectedProvider,
            onChanged: (value) {
              setState(() {
                _selectedProvider = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('Google Gemini'),
            subtitle: const Text('Gemini Pro'),
            value: 'gemini',
            groupValue: _selectedProvider,
            onChanged: (value) {
              setState(() {
                _selectedProvider = value!;
              });
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

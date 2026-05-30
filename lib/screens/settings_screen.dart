import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/settings_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/sync_service.dart';
import '../services/ai_service.dart';
import '../services/local_ai_service.dart';
import '../services/cactus_local_service.dart';
import '../services/device_capability.dart';
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
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

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
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    await notifier.saveSettings(
      openAIKey: _openAIKeyController.text.trim(),
      geminiKey: _geminiKeyController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    final provider = settings.aiProvider;
    final key = provider == 'openai'
        ? _openAIKeyController.text.trim()
        : _geminiKeyController.text.trim();

    if (provider == 'local' || provider == 'cactus' || key.isEmpty) {
      setState(() {
        _isTesting = false;
        _testResult =
            key.isEmpty ? 'No key to test' : 'Local AI: no test needed';
        _testSuccess = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Settings saved'),
            backgroundColor: AppTheme.primaryBlue),
      );
      return;
    }

    final aiService = AIService();
    final isValid = await aiService.testConnection(provider, key);

    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _testSuccess = isValid;
      _testResult = isValid
          ? '${provider == 'openai' ? 'OpenAI' : 'Gemini'} API key is valid ✓'
          : '${provider == 'openai' ? 'OpenAI' : 'Gemini'} API key is invalid ✗';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_testResult!),
        backgroundColor: isValid ? AppTheme.primaryBlue : Colors.red,
      ),
    );

    if (isValid) {
      final isOnline = ConnectivityChecker.instance.isConnected;
      if (isOnline && !SyncService.instance.isSyncing) {
        SyncService.instance.processPendingQueue();
      }
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
                  children: ThemeMode.values
                      .map((mode) => _buildThemeTile(mode, currentTheme))
                      .toList(),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
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
                    ref
                        .read(settingsProvider.notifier)
                        .setWeeklyGoal(value.round());
                  },
                ),
                Text(
                  'Aim for a consistent target to build your vocabulary habit.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('AI PROVIDER'),
          const SizedBox(height: 4),
          _buildDeviceInfo(),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _buildCard(
            child: Column(
              children: [
                _buildProviderTile('Local AI (llama.cpp)',
                    settings.aiProvider == 'local'
                        ? 'Offline-only, device CPU'
                        : 'Offline-only · ${_modelDisplayName(settings.localModelId)}',
                    'local',
                    settings.aiProvider),
                if (settings.aiProvider == 'local') ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildLocalModelDropdown(settings.localModelId),
                ],
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildProviderTile('Cactus AI (fast)',
                    'ARM-optimized engine · 15-50 tok/s',
                    'cactus',
                    settings.aiProvider),
                if (settings.aiProvider == 'cactus') ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildCactusModelDropdown(settings.cactusModelId),
                ],
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildProviderTile('Google Gemini', 'gemini-1.5-flash',
                    'gemini', settings.aiProvider),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildProviderTile(
                    'OpenAI', 'GPT-3.5 Turbo', 'openai', settings.aiProvider),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionHeader('MANAGE MODELS'),
          const SizedBox(height: 12),
          _buildModelManagementSection(),
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
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isTesting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update Keys'),
                  ),
                ),
                if (_testResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _testSuccess == true
                              ? Icons.check_circle
                              : Icons.error,
                          size: 18,
                          color:
                              _testSuccess == true ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _testResult!,
                            style: TextStyle(
                              fontSize: 13,
                              color: _testSuccess == true
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildDeviceInfo() {
    final device = DeviceCapability.instance;
    final tierLabel = switch (device.tier) {
      DeviceTier.low => 'Low-end',
      DeviceTier.mid => 'Mid-range',
      DeviceTier.high => 'High-end',
      DeviceTier.flagship => 'Flagship',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_android,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Device: $tierLabel · ${device.cpuCores} cores · '
              '${device.totalMemoryMB ~/ 1024} GB RAM · '
              '${device.optimalThreads} threads',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (device.gpuLayers > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'GPU',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
            ),
        ],
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
      case ThemeMode.system:
        title = 'System Default';
        break;
      case ThemeMode.light:
        title = 'Light';
        break;
      case ThemeMode.dark:
        title = 'Dark';
        break;
    }

    return RadioListTile<ThemeMode>(
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      value: mode,
      groupValue: current,
      activeColor: AppTheme.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onChanged: (v) {
        if (v != null) ref.read(themeModeProvider.notifier).setTheme(v);
      },
    );
  }

  Widget _buildProviderTile(
      String name, String sub, String value, String current) {
    final bool isLocal = value == 'local';
    final bool isCactus = value == 'cactus';
    final bool isLibAvailable =
        !isLocal || LocalAIService.isNativeLibraryAvailable();

    return RadioListTile<String>(
      title: Row(
        children: [
          Text(name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isLibAvailable ? null : Theme.of(context).disabledColor,
              )),
          if (isLocal && !isLibAvailable) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'UNAVAILABLE',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 9,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
          isLocal && !isLibAvailable
              ? 'Native engine missing in this build'
              : sub,
          style: TextStyle(
              fontSize: 12,
              color: isLibAvailable
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).disabledColor)),
      value: value,
      groupValue: current,
      activeColor: AppTheme.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onChanged: !isLibAvailable
          ? null
          : (v) async {
              if (v == null) return;

              if (v == 'local') {
                final settings = ref.read(settingsProvider);
                final validIds =
                    LocalAIService.availableModels.map((m) => m.id).toSet();
                final currentId = validIds.contains(settings.localModelId)
                    ? settings.localModelId
                    : LocalAIService.availableModels.first.id;
                final isDownloaded =
                    await LocalAIService().isModelDownloaded(currentId);

                if (!isDownloaded) {
                  if (!mounted) return;
                  final picked = await _showModelPickerDialog();
                  if (picked == null) return;
                  final success = await _showDownloadProgress(
                      LocalAIService().getModelConfig(picked));
                  if (success && mounted) {
                    ref.read(settingsProvider.notifier).setLocalModelId(picked);
                    ref.read(settingsProvider.notifier).setAIProvider(v);
                  }
                  return;
                }

                if (currentId != settings.localModelId && mounted) {
                  ref.read(settingsProvider.notifier).setLocalModelId(currentId);
                }
              }

              if (v == 'cactus') {
                final settings = ref.read(settingsProvider);
                final cactusId = settings.cactusModelId;
                final isDownloaded =
                    await CactusLocalService().isModelDownloaded(cactusId);

                if (!isDownloaded) {
                  if (!mounted) return;
                  final picked = await _showCactusModelPickerDialog();
                  if (picked == null) return;
                  final success =
                      await _showCactusDownloadProgress(picked);
                  if (success && mounted) {
                    ref.read(settingsProvider.notifier).setCactusModelId(picked);
                    ref.read(settingsProvider.notifier).setAIProvider(v);
                  }
                  return;
                }

                ref.read(settingsProvider.notifier).setAIProvider(v);
                return;
              }

              ref.read(settingsProvider.notifier).setAIProvider(v);
            },
    );
  }

  Widget _buildLocalModelDropdown(String currentId) {
    final localAi = LocalAIService();
    final validIds = LocalAIService.availableModels.map((m) => m.id).toSet();
    final safeId = validIds.contains(currentId)
        ? currentId
        : LocalAIService.availableModels.first.id;
    if (safeId != currentId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(settingsProvider.notifier)
            .setLocalModelId(safeId);
      });
    }
    return Padding(
      padding: const EdgeInsets.only(left: 64, right: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Model',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeId,
                isExpanded: true,
                items: LocalAIService.availableModels.map((config) {
                  final isActive = config.id == safeId;
                  final unsuitable = !localAi.isModelSuitable(config.id);
                  return DropdownMenuItem(
                    value: config.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(config.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                color: unsuitable ? Colors.orange : null,
                              )),
                        ),
                        if (unsuitable && !isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Slow',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange),
                            ),
                          )
                        else
                          Text(
                            isActive ? '✓ Active' : config.sizeStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive
                                  ? Colors.green
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) async {
                  if (v != null && v != currentId) {
                    final isDownloaded =
                        await LocalAIService().isModelDownloaded(v);
                    if (!isDownloaded) {
                      final config = LocalAIService().getModelConfig(v);
                      final success = await _showDownloadProgress(config);
                      if (success && mounted) {
                        ref.read(settingsProvider.notifier).setLocalModelId(v);
                      }
                    } else {
                      ref.read(settingsProvider.notifier).setLocalModelId(v);
                    }
                  }
                },
              ),
            ),
          ),
          Builder(builder: (context) {
            final warning = localAi.getModelWarning(currentId);
            if (warning == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      size: 14, color: Colors.orange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      warning,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Shows a picker dialog listing all 3 models. Returns the picked model id, or null if cancelled.
  Future<String?> _showModelPickerDialog() async {
    final downloaded = await LocalAIService().getDownloadedModels();
    final downloadedIds = downloaded.map((m) => m.$1.id).toSet();
    final localAi = LocalAIService();
    String? selectedId = LocalAIService.availableModels.first.id;

    return showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Model to Download'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: LocalAIService.availableModels.map((config) {
              final isDownloaded = downloadedIds.contains(config.id);
              final unsuitable = !localAi.isModelSuitable(config.id);
              return Column(
                children: [
                  RadioListTile<String>(
                    title: Row(
                      children: [
                        Expanded(
                            child: Text(config.displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: unsuitable ? Colors.orange : null,
                                ))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDownloaded
                                ? Colors.green.withOpacity(0.1)
                                : unsuitable
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isDownloaded
                                ? 'Downloaded'
                                : unsuitable
                                    ? '⚠ Slow'
                                    : config.sizeStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDownloaded
                                  ? Colors.green
                                  : unsuitable
                                      ? Colors.orange
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: unsuitable
                        ? Text(
                            localAi.getModelWarning(config.id) ?? '',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.orange),
                          )
                        : null,
                    value: config.id,
                    groupValue: selectedId,
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (v) {
                      setDialogState(() => selectedId = v);
                    },
                  ),
                  if (config.id != LocalAIService.availableModels.last.id)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                  downloadedIds.contains(selectedId) ? 'Select' : 'Download'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDownloadProgress(LocalModelConfig config) async {
    final progressNotifier = ValueNotifier<double>(0);
    final statusNotifier = ValueNotifier<String>('0%');
    final cancelToken = CancelToken();
    bool success = false;
    String? errorMsg;

    download() async {
      final result =
          await LocalAIService().downloadModel(config.id, (count, total) {
        if (total > 0) {
          final p = count / total;
          progressNotifier.value = p;
          statusNotifier.value = '${(p * 100).toStringAsFixed(1)}%';
        }
      }, cancelToken: cancelToken);
      success = result.isSuccess;
      errorMsg = result.message;
      if (result.message == 'Download cancelled') {
        errorMsg = null;
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    download();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Downloading ${config.displayName}'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Downloading weights (${config.sizeStr}). Please keep the app open and connected to Wi-Fi.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value > 0 ? value : null,
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, value, child) => Text(
                value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                cancelToken.cancel();
              },
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );

    if (!success && errorMsg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg!), backgroundColor: Colors.red),
      );
    }

    return success;
  }

  Widget _buildCactusModelDropdown(String currentId) {
    final cactus = CactusLocalService();
    final safeId = CactusLocalService.availableModels
            .any((m) => m.id == currentId)
        ? currentId
        : CactusLocalService.availableModels.first.id;
    if (safeId != currentId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(settingsProvider.notifier)
            .setCactusModelId(safeId);
      });
    }
    return Padding(
      padding: const EdgeInsets.only(left: 64, right: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Cactus Model',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeId,
                isExpanded: true,
                items: CactusLocalService.availableModels.map((config) {
                  return DropdownMenuItem(
                    value: config.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(config.displayName,
                            style: const TextStyle(fontSize: 14))),
                        Text(
                          config.sizeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) async {
                  if (v != null && v != currentId) {
                    final isDownloaded =
                        await CactusLocalService().isModelDownloaded(v);
                    if (!isDownloaded) {
                      final success =
                          await _showCactusDownloadProgress(v);
                      if (success && mounted) {
                        ref
                            .read(settingsProvider.notifier)
                            .setCactusModelId(v);
                      }
                    } else {
                      ref
                          .read(settingsProvider.notifier)
                          .setCactusModelId(v);
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showCactusModelPickerDialog() async {
    final models = CactusLocalService.availableModels;
    final dlStatus = <String, bool>{};
    for (final m in models) {
      dlStatus[m.id] = await CactusLocalService().isModelDownloaded(m.id);
    }
    String? selectedId = models.first.id;

    return showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Cactus Model to Download'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: models.map((config) {
              final isDl = dlStatus[config.id] ?? false;
              return Column(
                children: [
                  RadioListTile<String>(
                    title: Row(
                      children: [
                        Expanded(
                            child: Text(config.displayName,
                                style: const TextStyle(fontSize: 14))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDl
                                ? Colors.green.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isDl ? 'Downloaded' : config.sizeStr,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDl
                                  ? Colors.green
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    value: config.id,
                    groupValue: selectedId,
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (v) {
                      setDialogState(() => selectedId = v);
                    },
                  ),
                  if (config.id != models.last.id)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                  (dlStatus[selectedId] ?? false) ? 'Select' : 'Download'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showCactusDownloadProgress(String modelId) async {
    final config = CactusLocalService().getModelConfig(modelId);
    final progressNotifier = ValueNotifier<double>(0);
    final statusNotifier = ValueNotifier<String>('Starting...');
    final cancelToken = CancelToken();
    bool success = false;
    String? errorMsg;

    download() async {
      final result = await CactusLocalService().downloadModel(
        modelId,
        (count, total) {
          if (total > 0) {
            final p = count / total;
            progressNotifier.value = p;
            statusNotifier.value = '${(p * 100).toStringAsFixed(1)}%';
          }
        },
        cancelToken: cancelToken,
      );
      success = result.isSuccess;
      errorMsg = result.message;
      if (result.message == 'Download cancelled') {
        errorMsg = null;
      }
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }

    download();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Downloading ${config.displayName}'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Downloading weights (${config.sizeStr}). Keep app open.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 24),
            ValueListenableBuilder<double>(
              valueListenable: progressNotifier,
              builder: (context, value, child) => LinearProgressIndicator(
                value: value > 0 ? value : null,
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, value, child) => Text(
                value,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                cancelToken.cancel();
              },
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );

    if (!success && errorMsg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg!), backgroundColor: Colors.red),
      );
    }

    return success;
  }

  String _modelDisplayName(String modelId) {
    final llamaConfig = LocalAIService.availableModels
        .where((m) => m.id == modelId);
    if (llamaConfig.isNotEmpty) return llamaConfig.first.displayName;
    final cactusConfig = CactusLocalService.availableModels
        .where((m) => m.id == modelId);
    if (cactusConfig.isNotEmpty) return cactusConfig.first.displayName;
    return modelId;
  }

  Widget _buildModelManagementSection() {
    final localModels = LocalAIService.availableModels;
    final cactusModels = CactusLocalService.availableModels;
    return Consumer(builder: (context, ref, child) {
      final settings = ref.watch(settingsProvider);
      final allConfigs = [
        ...localModels.map((m) => _ModelInfo(
            id: m.id,
            displayName: m.displayName,
            sizeStr: m.sizeStr,
            provider: 'local',
            isActive: settings.localModelId == m.id &&
                settings.aiProvider == 'local')),
        ...cactusModels.map((m) => _ModelInfo(
            id: m.id,
            displayName: m.displayName,
            sizeStr: m.sizeStr,
            provider: 'cactus',
            isActive: settings.cactusModelId == m.id &&
                settings.aiProvider == 'cactus')),
      ];
      return FutureBuilder<Set<String>>(
        future: _getDownloadedModelIds(),
        builder: (context, snapshot) {
          final downloadedIds = snapshot.data ?? {};
          return _buildCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final info in allConfigs) ...[
                  if (downloadedIds.contains('${info.provider}:${info.id}'))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          if (info.isActive)
                            const Icon(Icons.check_circle,
                                size: 16, color: Colors.green),
                          if (!info.isActive)
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(info.displayName,
                                    style: const TextStyle(fontSize: 14)),
                                Text('${info.sizeStr} · ${info.provider == 'local' ? 'llama.cpp' : 'Cactus'}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: Colors.redAccent,
                            tooltip: 'Delete downloaded model',
                            onPressed: () => _deleteModelDialog(info),
                          ),
                        ],
                      ),
                    ),
                ],
                if (downloadedIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No models downloaded yet.',
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  Future<Set<String>> _getDownloadedModelIds() async {
    final ids = <String>{};
    for (final m in LocalAIService.availableModels) {
      if (await LocalAIService().isModelDownloaded(m.id)) {
        ids.add('local:${m.id}');
      }
    }
    for (final m in CactusLocalService.availableModels) {
      if (await CactusLocalService().isModelDownloaded(m.id)) {
        ids.add('cactus:${m.id}');
      }
    }
    return ids;
  }

  Future<void> _deleteModelDialog(_ModelInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${info.displayName}?'),
        content: Text(
            'This will permanently delete the downloaded model files (${info.sizeStr}).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final settings = ref.read(settingsProvider);
    bool deleted;
    if (info.provider == 'local') {
      deleted = await LocalAIService().deleteModel(info.id);
      if (info.id == settings.localModelId && mounted) {
        ref.read(settingsProvider.notifier).setLocalModelId(
            LocalAIService.availableModels.first.id);
      }
    } else {
      deleted =
          await CactusLocalService().deleteModel(info.id);
      if (info.id == settings.cactusModelId && mounted) {
        ref.read(settingsProvider.notifier).setCactusModelId(
            CactusLocalService.availableModels.first.id);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(deleted
              ? '${info.displayName} deleted'
              : 'Model not found on disk'),
        ),
      );
    }
  }

  Widget _buildKeyField(
      {required TextEditingController controller,
      required String label,
      required String hint}) {
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
        prefixIcon: const Icon(Icons.vpn_key_rounded,
            size: 20, color: AppTheme.primaryBlue),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _ModelInfo {
  final String id;
  final String displayName;
  final String sizeStr;
  final String provider;
  final bool isActive;
  const _ModelInfo({
    required this.id,
    required this.displayName,
    required this.sizeStr,
    required this.provider,
    required this.isActive,
  });
}

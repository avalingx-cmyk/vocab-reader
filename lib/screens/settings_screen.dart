import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/settings_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/sync_service.dart';
import '../services/ai_service.dart';
import '../services/cactus_local_service.dart';
import '../services/device_capability.dart';
import '../models/word.dart';
import '../models/user_level.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';

@visibleForTesting
String? benchmarkContextForAttempt({
  required String word,
  required String userContext,
  required int attempt,
  required String? previousFailureStage,
}) {
  final trimmed = userContext.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }

  final shouldAddFallback = attempt > 1 &&
      (previousFailureStage == 'validation-rejected' ||
          previousFailureStage == 'parse-failed');
  if (!shouldAddFallback) {
    return null;
  }

  return 'I found the word "$word" in a book and want a clear vocabulary explanation.';
}

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
  final _benchmarkWordController = TextEditingController();
  final _benchmarkContextController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;
  bool _isBenchmarking = false;
  String? _benchmarkStatus;
  List<_BenchmarkResult> _benchmarkResults = const [];
  String? _benchmarkWord;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _openAIKeyController.text = settings.openAIKey ?? '';
    _geminiKeyController.text = settings.geminiKey ?? '';
    _benchmarkWordController.text = 'ephemeral';
  }

  @override
  void dispose() {
    _openAIKeyController.dispose();
    _geminiKeyController.dispose();
    _benchmarkWordController.dispose();
    _benchmarkContextController.dispose();
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

    if (provider == 'cactus' || key.isEmpty) {
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
                _buildLocalModelTile(
                  currentProvider: settings.aiProvider,
                  currentModelId: settings.cactusModelId,
                ),
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
    return RadioListTile<String>(
      title: Text(name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          )),
      subtitle: Text(sub,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
      value: value,
      groupValue: current,
      activeColor: AppTheme.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onChanged: (v) async {
        if (v == null) return;

        if (v == 'cactus') {
          final cactusId = CactusLocalService.defaultModelId;
          final isDownloaded =
              await CactusLocalService().isModelDownloaded(cactusId);

          if (!isDownloaded) {
            final success = await _showCactusDownloadProgress(cactusId);
            if (success && mounted) {
              ref.read(settingsProvider.notifier).setCactusModelId(cactusId);
              ref.read(settingsProvider.notifier).setAIProvider(v);
            }
            return;
          }

          ref.read(settingsProvider.notifier).setCactusModelId(cactusId);
          ref.read(settingsProvider.notifier).setAIProvider(v);
          return;
        }

        ref.read(settingsProvider.notifier).setAIProvider(v);
      },
    );
  }

  Widget _buildLocalModelTile({
    required String currentProvider,
    required String currentModelId,
  }) {
    final config = CactusLocalService().getModelConfig(currentModelId);
    return FutureBuilder<bool>(
      future: CactusLocalService().isModelDownloaded(config.id),
      builder: (context, snapshot) {
        final isDownloaded = snapshot.data ?? false;
        final subtitle = isDownloaded
            ? 'Downloaded · ${config.sizeStr}'
            : 'Tap to download · ${config.sizeStr}';

        return RadioListTile<String>(
          title: const Text(
            'Local Model',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDownloaded
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          secondary: Icon(
            isDownloaded ? Icons.check_circle : Icons.download_rounded,
            color: isDownloaded ? Colors.green : AppTheme.primaryBlue,
            size: 20,
          ),
          toggleable: false,
          value: 'cactus',
          groupValue: currentProvider,
          activeColor: AppTheme.primaryBlue,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onChanged: (v) async {
            if (v == null) return;

            final cactusId = CactusLocalService.defaultModelId;
            if (!isDownloaded) {
              final shouldDownload = await _confirmDownloadLocalModel(config.sizeStr);
              if (shouldDownload != true) return;

              final success = await _showCactusDownloadProgress(cactusId);
              if (!success || !mounted) return;
            }

            await ref.read(settingsProvider.notifier).setCactusModelId(cactusId);
            await ref.read(settingsProvider.notifier).setAIProvider(v);
            if (mounted) {
              setState(() {});
            }
          },
        );
      },
    );
  }

  Future<bool?> _confirmDownloadLocalModel(String sizeStr) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Download local model?'),
        content: Text(
          'The local model is not downloaded yet. Download $sizeStr now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Download'),
          ),
        ],
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
        title: const Text('Downloading local model'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Downloading offline model (${config.sizeStr}). Keep app open.',
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

  Future<Set<String>> _getDownloadedModelIds() async {
    final ids = <String>{};
    for (final m in CactusLocalService.availableModels) {
      if (await CactusLocalService().isModelDownloaded(m.id)) {
        ids.add('cactus:${m.id}');
      }
    }
    return ids;
  }

  // ignore: unused_element
  Widget _buildBenchmarkSection() {
    return _buildCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compare downloaded Cactus models on this device.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Runs the same word through every downloaded Cactus model and shows elapsed time plus the generated summary.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _benchmarkWordController,
            decoration: const InputDecoration(
              labelText: 'Word',
              hintText: 'e.g. ephemeral',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _benchmarkContextController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Context (optional)',
              hintText: 'Sentence where you saw the word',
            ),
          ),
          if (_benchmarkStatus != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_isBenchmarking)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_isBenchmarking) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _benchmarkStatus!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBenchmarking ? null : _startBenchmarkFlow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(_isBenchmarking
                  ? 'Benchmark Running...'
                  : 'Benchmark Downloaded Models'),
            ),
          ),
          if (_benchmarkResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _benchmarkWord == null
                  ? 'Latest Results'
                  : 'Latest Results: $_benchmarkWord',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _benchmarkResults.length; i++) ...[
              _buildBenchmarkResultCard(context, _benchmarkResults[i]),
              if (i != _benchmarkResults.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _startBenchmarkFlow() async {
    final word = _benchmarkWordController.text.trim();
    if (word.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a word to benchmark first.')),
      );
      return;
    }

    final request = _BenchmarkRequest(
      word: word,
      context: _benchmarkContextController.text.trim(),
    );

    final downloadedIds = await _getDownloadedModelIds();
    final candidates = _getBenchmarkCandidates(downloadedIds);
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Download at least one Cactus model first.')),
      );
      return;
    }

    setState(() {
      _isBenchmarking = true;
      _benchmarkStatus = 'Preparing ${candidates.length} model(s)...';
    });

    final results = <_BenchmarkResult>[];
    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      if (!mounted) return;
      setState(() {
        _benchmarkStatus =
            'Running ${i + 1}/${candidates.length}: ${candidate.displayName}';
      });
      results.add(await _runBenchmark(candidate, request));
    }

    final scoredResults = _applySpeedScores(results);
    scoredResults.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.elapsedMs.compareTo(b.elapsedMs);
    });

    if (!mounted) return;
    setState(() {
      _isBenchmarking = false;
      _benchmarkStatus = 'Completed ${scoredResults.length} benchmark(s).';
      _benchmarkResults = scoredResults;
      _benchmarkWord = request.word;
    });
  }

  List<_BenchmarkCandidate> _getBenchmarkCandidates(Set<String> downloadedIds) {
    final candidates = <_BenchmarkCandidate>[];

    for (final model in CactusLocalService.availableModels) {
      if (downloadedIds.contains('cactus:${model.id}')) {
        candidates.add(_BenchmarkCandidate(
          provider: 'cactus',
          modelId: model.id,
          displayName: model.displayName,
          subtitle: 'Cactus · ${model.sizeStr}',
          sizeMb: model.sizeMB,
        ));
      }
    }

    candidates.sort((a, b) {
      final sizeCompare = a.sizeMb.compareTo(b.sizeMb);
      if (sizeCompare != 0) return sizeCompare;
      return a.displayName.compareTo(b.displayName);
    });

    return candidates;
  }

  Future<_BenchmarkResult> _runBenchmark(
    _BenchmarkCandidate candidate,
    _BenchmarkRequest request,
  ) async {
    final preflight = await _preflightBenchmarkCandidate(candidate);
    if (!preflight.isReady) {
      return _BenchmarkResult(
        candidate: candidate,
        elapsedMs: 0,
        loadMs: 0,
        generateMs: 0,
        success: false,
        score: 0,
        failureStage: preflight.failureStage,
        error: preflight.message,
      );
    }

    var totalLoadMs = 0;
    var totalGenerateMs = 0;
    String? lastError;
    String? lastFailureStage;

    for (var attempt = 1; attempt <= 2; attempt++) {
      if (mounted) {
        setState(() {
          _benchmarkStatus = attempt == 1
              ? 'Running ${candidate.displayName}...'
              : 'Retrying ${candidate.displayName} ($attempt/2)...';
        });
      }

      final service = AIService();
      service.configure(
        provider: candidate.provider,
        localModelId: candidate.modelId,
      );
      try {
        final benchmarkContext = benchmarkContextForAttempt(
          word: request.word,
          userContext: request.context,
          attempt: attempt,
          previousFailureStage: lastFailureStage,
        );
        final result = await service.generateSummaryDetailed(
          word: request.word,
          context: benchmarkContext,
          level: UserLevel.beginner,
          keepAlive: true,
        );
        totalLoadMs += result.loadMs;
        totalGenerateMs += result.generateMs;

        if (result.summary != null) {
          final sectionScores = _scoreBenchmarkSections(
            request.word,
            result.summary!,
          );
          return _BenchmarkResult(
            candidate: candidate,
            elapsedMs: totalLoadMs + totalGenerateMs,
            loadMs: totalLoadMs,
            generateMs: totalGenerateMs,
            success: true,
            score: 0,
            definitionScore: sectionScores.definition,
            exampleScore: sectionScores.examples,
            similarScore: sectionScores.similarWords,
            speedScore: 0,
            summary: result.summary,
            attempts: attempt,
          );
        }

        if (result.partialSummary != null &&
            result.failureStage == 'validation-rejected') {
          final sectionScores = _scoreBenchmarkSections(
            request.word,
            result.partialSummary!,
          );
          return _BenchmarkResult(
            candidate: candidate,
            elapsedMs: totalLoadMs + totalGenerateMs,
            loadMs: totalLoadMs,
            generateMs: totalGenerateMs,
            success: true,
            score: 0,
            definitionScore: sectionScores.definition,
            exampleScore: sectionScores.examples,
            similarScore: sectionScores.similarWords,
            speedScore: 0,
            summary: result.partialSummary,
            attempts: attempt,
            warning: result.errorMessage,
          );
        }

        lastFailureStage = result.failureStage ?? 'generation-failed';
        lastError = result.errorMessage ?? 'Benchmark generation failed.';
      } catch (e) {
        lastFailureStage = 'generation-failed';
        lastError = e.toString();
      }

      if (attempt < 2) {
        await _unloadBenchmarkModel();
      }
    }

    return _BenchmarkResult(
      candidate: candidate,
      elapsedMs: totalLoadMs + totalGenerateMs,
      loadMs: totalLoadMs,
      generateMs: totalGenerateMs,
      success: false,
      score: 0,
      failureStage: lastFailureStage ?? 'generation-failed',
      error: lastError ?? 'No summary generated',
      attempts: 2,
    );
  }

  Future<_BenchmarkPreflightResult> _preflightBenchmarkCandidate(
    _BenchmarkCandidate candidate,
  ) async {
    final isDownloaded =
        await CactusLocalService().isModelDownloaded(candidate.modelId);
    if (!isDownloaded) {
      return _BenchmarkPreflightResult(
        isReady: false,
        failureStage: 'not-downloaded',
        message: '${candidate.displayName} is not fully downloaded.',
      );
    }
    final modelPath =
        await CactusLocalService().getModelPath(candidate.modelId);
    final modelDir = Directory(modelPath);
    if (!await modelDir.exists()) {
      return _BenchmarkPreflightResult(
        isReady: false,
        failureStage: 'not-downloaded',
        message: 'Model directory is missing at $modelPath.',
      );
    }
    final configFile = File('$modelPath/config.json');
    if (!await configFile.exists()) {
      return _BenchmarkPreflightResult(
        isReady: false,
        failureStage: 'model-incomplete',
        message: '${candidate.displayName} is missing config.json.',
      );
    }
    return const _BenchmarkPreflightResult(isReady: true);
  }

  Future<void> _unloadBenchmarkModel() async {
    await CactusLocalService().unloadModel();
  }

  _BenchmarkSectionScores _scoreBenchmarkSections(
    String word,
    WordSummary summary,
  ) {
    final normalizedWord = _normalizeBenchmarkText(word);
    final definition = summary.definition.trim();
    final useCases =
        summary.useCases.where((e) => e.trim().isNotEmpty).toList();
    final similarWords =
        summary.similarWords.where((e) => e.trim().isNotEmpty).toList();

    return _BenchmarkSectionScores(
      definition: _scoreDefinition(normalizedWord, definition),
      examples: _scoreUseCases(normalizedWord, useCases),
      similarWords: _scoreSimilarWords(normalizedWord, similarWords),
    );
  }

  int _scoreDefinition(String normalizedWord, String definition) {
    if (definition.isEmpty) return 0;

    var score = 10;
    final words = _benchmarkWords(definition);
    final normalizedDefinition = _normalizeBenchmarkText(definition);

    if (words.length >= 4 && words.length <= 14) {
      score += 8;
    } else if (words.length >= 2 && words.length <= 18) {
      score += 6;
    }

    if (!_containsInstructionLeak(definition)) score += 6;
    if (!_containsWordFamily(normalizedDefinition, normalizedWord)) score += 4;
    if (definition.contains(RegExp(r'[.,;:!?]'))) score += 2;
    if (_looksDirectDefinition(definition)) score += 5;

    return score.clamp(0, 25);
  }

  int _scoreUseCases(String normalizedWord, List<String> useCases) {
    var score = 0;

    for (final example in useCases.take(3)) {
      final words = _benchmarkWords(example);
      final normalizedExample = _normalizeBenchmarkText(example);
      var itemScore = 0;

      if (words.length >= 6 && words.length <= 16) {
        itemScore += 6;
      } else if (words.length >= 4 && words.length <= 24) {
        itemScore += 3;
      }

      if (_containsWordFamily(normalizedExample, normalizedWord))
        itemScore += 4;
      if (example.contains(RegExp(r'[.!?]'))) itemScore += 2;
      if (!_containsInstructionLeak(example)) itemScore += 2;
      if (_looksNaturalExample(example)) itemScore += 2;

      score += itemScore;
    }

    if (useCases.length >= 3) score += 5;
    if (_allDistinct(useCases)) score += 4;
    if (_variedSentenceStarts(useCases)) score += 3;
    return score.clamp(0, 40);
  }

  int _scoreSimilarWords(String normalizedWord, List<String> similarWords) {
    var score = 0;
    final seen = <String>{};

    for (final item in similarWords.take(5)) {
      final normalizedItem = _normalizeBenchmarkText(item);
      final wordCount = _benchmarkWords(item).length;
      var itemScore = 0;

      if (normalizedItem.isEmpty) continue;
      if (wordCount >= 1 && wordCount <= 3) {
        itemScore += 4;
      } else {
        itemScore += 2;
      }

      if (!_containsWordFamily(normalizedItem, normalizedWord)) itemScore += 3;
      if (!_containsInstructionLeak(item)) itemScore += 2;
      if (!seen.contains(normalizedItem)) itemScore += 2;

      seen.add(normalizedItem);
      score += itemScore;
    }

    if (similarWords.length >= 3) score += 4;
    if (_allDistinct(similarWords)) score += 3;
    return score.clamp(0, 25);
  }

  List<_BenchmarkResult> _applySpeedScores(List<_BenchmarkResult> results) {
    final successful = results.where((result) => result.success).toList();
    if (successful.isEmpty) return results;

    final fastest = successful
        .map((result) => result.elapsedMs)
        .reduce((a, b) => a < b ? a : b);
    final slowest = successful
        .map((result) => result.elapsedMs)
        .reduce((a, b) => a > b ? a : b);

    return results.map((result) {
      if (!result.success) return result;

      final speedScore = slowest == fastest
          ? 10
          : ((slowest - result.elapsedMs) * 10 / (slowest - fastest))
              .round()
              .clamp(1, 10);
      final totalScore = result.definitionScore +
          result.exampleScore +
          result.similarScore +
          speedScore;

      return result.copyWith(
        speedScore: speedScore,
        score: totalScore,
      );
    }).toList();
  }

  bool _containsInstructionLeak(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('json') ||
        normalized.contains('schema') ||
        normalized.contains('instruction') ||
        normalized.contains('natural sentence using') ||
        normalized.contains('plain-english definition') ||
        normalized.contains('copy these instructions');
  }

  bool _looksDirectDefinition(String text) {
    final normalized = text.toLowerCase();
    return !normalized.contains('used to describe') &&
        !normalized.contains('state of being') &&
        !normalized.contains('meaning it');
  }

  bool _looksNaturalExample(String text) {
    final normalized = text.toLowerCase();
    return !normalized.contains('in its') &&
        !normalized.contains('can be considered') &&
        !normalized.contains('used in');
  }

  bool _allDistinct(List<String> items) {
    final normalized = items
        .map(_normalizeBenchmarkText)
        .where((item) => item.isNotEmpty)
        .toList();
    return normalized.toSet().length == normalized.length;
  }

  bool _variedSentenceStarts(List<String> items) {
    final starts = items
        .map((item) => _benchmarkWords(item))
        .where((words) => words.isNotEmpty)
        .map((words) => words.first)
        .toSet();
    return starts.length >= 2;
  }

  bool _containsWordFamily(String text, String normalizedWord) {
    if (normalizedWord.isEmpty || text.isEmpty) return false;
    if (text.contains(normalizedWord)) return true;
    if (normalizedWord.length < 5) return false;
    final stem = normalizedWord.substring(0, normalizedWord.length - 2);
    return stem.length >= 3 && text.contains(stem);
  }

  String _normalizeBenchmarkText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ').trim();
  }

  List<String> _benchmarkWords(String value) {
    return _normalizeBenchmarkText(value)
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  Widget _buildBenchmarkResultCard(
    BuildContext cardContext,
    _BenchmarkResult result,
  ) {
    final summary = result.summary;
    final colorScheme = Theme.of(cardContext).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.candidate.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      result.candidate.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${result.elapsedMs} ms',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Load ${result.loadMs} ms  |  Generate ${result.generateMs} ms',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.success ? 'Score: ${result.score}/100' : 'Failed',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: result.success ? Colors.green : Colors.redAccent,
            ),
          ),
          if (result.attempts > 1) ...[
            const SizedBox(height: 4),
            Text(
              'Attempts: ${result.attempts}',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (result.success) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildScoreChip(
                    'Definition', '${result.definitionScore}/25', colorScheme),
                _buildScoreChip(
                    'Examples', '${result.exampleScore}/40', colorScheme),
                _buildScoreChip(
                    'Similar', '${result.similarScore}/25', colorScheme),
                _buildScoreChip(
                    'Speed', '${result.speedScore}/10', colorScheme),
              ],
            ),
          ],
          if (result.warning != null) ...[
            const SizedBox(height: 8),
            Text(
              result.warning!,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (!result.success)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.failureStage != null)
                  Text(
                    'Stage: ${result.failureStage}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (result.failureStage != null) const SizedBox(height: 4),
                Text(
                  result.error ?? 'Unknown error',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ),
          if (summary != null) ...[
            Text(summary.definition, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 10),
            Text(
              summary.useCases.join('\n'),
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              summary.similarWords.join(', '),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreChip(
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
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

class _BenchmarkRequest {
  final String word;
  final String context;

  const _BenchmarkRequest({
    required this.word,
    required this.context,
  });
}

class _BenchmarkCandidate {
  final String provider;
  final String modelId;
  final String displayName;
  final String subtitle;
  final int sizeMb;

  const _BenchmarkCandidate({
    required this.provider,
    required this.modelId,
    required this.displayName,
    required this.subtitle,
    required this.sizeMb,
  });
}

class _BenchmarkResult {
  final _BenchmarkCandidate candidate;
  final int elapsedMs;
  final int loadMs;
  final int generateMs;
  final int attempts;
  final bool success;
  final int score;
  final int definitionScore;
  final int exampleScore;
  final int similarScore;
  final int speedScore;
  final String? failureStage;
  final String? warning;
  final WordSummary? summary;
  final String? error;

  const _BenchmarkResult({
    required this.candidate,
    required this.elapsedMs,
    required this.loadMs,
    required this.generateMs,
    this.attempts = 1,
    required this.success,
    required this.score,
    this.definitionScore = 0,
    this.exampleScore = 0,
    this.similarScore = 0,
    this.speedScore = 0,
    this.failureStage,
    this.warning,
    this.summary,
    this.error,
  });

  _BenchmarkResult copyWith({
    int? score,
    int? definitionScore,
    int? exampleScore,
    int? similarScore,
    int? speedScore,
    String? warning,
  }) {
    return _BenchmarkResult(
      candidate: candidate,
      elapsedMs: elapsedMs,
      loadMs: loadMs,
      generateMs: generateMs,
      attempts: attempts,
      success: success,
      score: score ?? this.score,
      definitionScore: definitionScore ?? this.definitionScore,
      exampleScore: exampleScore ?? this.exampleScore,
      similarScore: similarScore ?? this.similarScore,
      speedScore: speedScore ?? this.speedScore,
      failureStage: failureStage,
      warning: warning,
      summary: summary,
      error: error,
    );
  }
}

class _BenchmarkPreflightResult {
  final bool isReady;
  final String? failureStage;
  final String? message;

  const _BenchmarkPreflightResult({
    required this.isReady,
    this.failureStage,
    this.message,
  });
}

class _BenchmarkSectionScores {
  final int definition;
  final int examples;
  final int similarWords;

  const _BenchmarkSectionScores({
    required this.definition,
    required this.examples,
    required this.similarWords,
  });
}

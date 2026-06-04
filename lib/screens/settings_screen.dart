import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_level.dart';
import '../providers/model_readiness_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/cactus_local_service.dart';
import '../theme/app_theme.dart';

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

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final model = ref.watch(modelReadinessProvider);
    final modelNotifier = ref.read(modelReadinessProvider.notifier);
    final modelConfig = CactusLocalService().getModelConfig(settings.cactusModelId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: modelNotifier.refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSectionHeader(context, 'APPEARANCE'),
            const SizedBox(height: 12),
            _buildCard(
              context,
              child: RadioGroup<ThemeMode>(
                groupValue: ref.watch(themeModeProvider),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setTheme(value);
                  }
                },
                child: Column(
                  children: ThemeMode.values
                      .map((mode) => _buildThemeTile(mode))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildSectionHeader(context, 'LEARNER LEVEL'),
            const SizedBox(height: 12),
            _buildCard(
              context,
              child: RadioGroup<UserLevel>(
                groupValue: settings.userLevel,
                onChanged: (value) {
                  if (value != null) {
                    ref.read(settingsProvider.notifier).setUserLevel(value);
                  }
                },
                child: Column(
                  children: UserLevel.values
                      .map((level) => _buildLevelTile(level))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildSectionHeader(context, 'OFFLINE AI'),
            const SizedBox(height: 12),
            _buildCard(
              context,
              child: _ModelStatusTile(
                state: model,
                modelLabel: modelConfig.displayName,
                modelSize: modelConfig.sizeStr,
                onDownload: modelNotifier.download,
                onRepair: modelNotifier.repair,
                onCancelDownload: modelNotifier.cancelDownload,
                onRefresh: modelNotifier.refresh,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'BookBeam works without accounts. On Android, offline AI summaries run on-device after the model download finishes.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
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

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: child,
        ),
      ),
    );
  }

  Widget _buildThemeTile(ThemeMode mode) {
    final title = switch (mode) {
      ThemeMode.system => 'System Default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

    return RadioListTile<ThemeMode>(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      value: mode,
      activeColor: AppTheme.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildLevelTile(UserLevel level) {
    return RadioListTile<UserLevel>(
      title: Text(
        level.displayName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(level.description),
      value: level,
      activeColor: AppTheme.primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _ModelStatusTile extends StatelessWidget {
  const _ModelStatusTile({
    required this.state,
    required this.modelLabel,
    required this.modelSize,
    required this.onDownload,
    required this.onRepair,
    required this.onCancelDownload,
    required this.onRefresh,
  });

  final ModelReadinessState state;
  final String modelLabel;
  final String modelSize;
  final Future<void> Function() onDownload;
  final Future<void> Function() onRepair;
  final VoidCallback onCancelDownload;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForState(), color: _colorForState(theme), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  state.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$modelLabel · $modelSize',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (state.status == ModelReadinessStatus.downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: state.progress > 0 ? state.progress : null),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: switch (state.status) {
                  ModelReadinessStatus.notDownloaded => () => onDownload(),
                  ModelReadinessStatus.downloading => onCancelDownload,
                  ModelReadinessStatus.repairNeeded => () => onRepair(),
                  _ => null,
                },
                child: Text(state.ctaLabel),
              ),
              OutlinedButton(
                onPressed: () => onRefresh(),
                child: const Text('Refresh Status'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForState() {
    return switch (state.status) {
      ModelReadinessStatus.ready => Icons.check_circle,
      ModelReadinessStatus.downloading => Icons.download_rounded,
      ModelReadinessStatus.repairNeeded => Icons.build_circle_outlined,
      ModelReadinessStatus.unsupported => Icons.devices_other_rounded,
      ModelReadinessStatus.notDownloaded => Icons.download_for_offline_outlined,
      ModelReadinessStatus.checking => Icons.hourglass_top_rounded,
    };
  }

  Color _colorForState(ThemeData theme) {
    return switch (state.status) {
      ModelReadinessStatus.ready => Colors.green,
      ModelReadinessStatus.downloading => AppTheme.primaryBlue,
      ModelReadinessStatus.repairNeeded => Colors.orange,
      ModelReadinessStatus.unsupported => theme.colorScheme.onSurfaceVariant,
      ModelReadinessStatus.notDownloaded => AppTheme.primaryBlue,
      ModelReadinessStatus.checking => theme.colorScheme.onSurfaceVariant,
    };
  }
}

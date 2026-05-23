import 'dart:io';
import 'dart:math';

enum DeviceTier {
  low,
  mid,
  high,
  flagship,
}

class DeviceCapability {
  final int cpuCores;
  final int totalMemoryMB;
  final bool isArm64;
  final DeviceTier tier;

  DeviceCapability({
    required this.cpuCores,
    required this.totalMemoryMB,
    required this.isArm64,
    required this.tier,
  });

  static DeviceCapability? _instance;
  static DeviceCapability get instance => _instance ??= detect();

  static DeviceCapability detect() {
    final cores = Platform.numberOfProcessors;
    final memMB = _estimateMemoryMB();
    final arm64 = _isArm64();
    final tier = _classifyTier(cores, memMB);

    return DeviceCapability(
      cpuCores: cores,
      totalMemoryMB: memMB,
      isArm64: arm64,
      tier: tier,
    );
  }

  static int _estimateMemoryMB() {
    if (Platform.isAndroid || Platform.isIOS) {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return 2048;
      final mem = Platform.environment['MEMINFO_TOTAL'];
      if (mem != null) return int.tryParse(mem) ?? 4096;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 8192;
    }
    return 4096;
  }

  static bool _isArm64() {
    if (Platform.isAndroid) return true;
    if (Platform.isIOS) return true;
    return false;
  }

  static DeviceTier _classifyTier(int cores, int memMB) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return DeviceTier.flagship;
    }
    if (cores >= 8 && memMB >= 8000) return DeviceTier.flagship;
    if (cores >= 6 && memMB >= 4000) return DeviceTier.high;
    if (cores >= 4 && memMB >= 2500) return DeviceTier.mid;
    return DeviceTier.low;
  }

  int get optimalThreads {
    if (Platform.isAndroid) {
      switch (tier) {
        case DeviceTier.flagship:
        case DeviceTier.high:
          return 2;
        case DeviceTier.mid:
          return 2;
        case DeviceTier.low:
          return 1;
      }
    }
    switch (tier) {
      case DeviceTier.flagship:
        return min(cpuCores, 8);
      case DeviceTier.high:
        return min(cpuCores, 6);
      case DeviceTier.mid:
        return max(2, min(cpuCores - 2, 4));
      case DeviceTier.low:
        return max(1, min(cpuCores - 2, 2));
    }
  }

  int get optimalBatchSize {
    switch (tier) {
      case DeviceTier.flagship:
        return 512;
      case DeviceTier.high:
        return 256;
      case DeviceTier.mid:
        return 128;
      case DeviceTier.low:
        return 64;
    }
  }

  int get optimalContextSize {
    switch (tier) {
      case DeviceTier.flagship:
        return 768;
      case DeviceTier.high:
        return 512;
      case DeviceTier.mid:
        return 384;
      case DeviceTier.low:
        return 256;
    }
  }

  int get optimalMaxTokens {
    switch (tier) {
      case DeviceTier.flagship:
        return 120;
      case DeviceTier.high:
        return 80;
      case DeviceTier.mid:
        return 60;
      case DeviceTier.low:
        return 50;
    }
  }

  int get generationTimeoutSeconds {
    switch (tier) {
      case DeviceTier.flagship:
        return 180;
      case DeviceTier.high:
        return 240;
      case DeviceTier.mid:
        return 300;
      case DeviceTier.low:
        return 360;
    }
  }

  int get gpuLayers {
    if (Platform.isAndroid) {
      return 0;
    }
    switch (tier) {
      case DeviceTier.flagship:
        return Platform.isWindows || Platform.isLinux ? 99 : 0;
      case DeviceTier.high:
        return Platform.isWindows || Platform.isLinux ? 99 : 0;
      case DeviceTier.mid:
      case DeviceTier.low:
        return 0;
    }
  }

  bool get shouldQuantizeKvCache =>
      tier == DeviceTier.low || tier == DeviceTier.mid;

  bool canRunModel(int modelSizeMB) {
    final minFreeMB = totalMemoryMB ~/ 3;
    return modelSizeMB < minFreeMB;
  }

  String get modelRecommendation {
    switch (tier) {
      case DeviceTier.flagship:
        return 'qwen-hq';
      case DeviceTier.high:
        return 'smolm-360';
      case DeviceTier.mid:
        return 'smolm-360';
      case DeviceTier.low:
        return 'smolm-135';
    }
  }

  @override
  String toString() => 'DeviceCapability(tier=$tier, cores=$cpuCores, '
      'mem=${totalMemoryMB}MB, arm64=$isArm64, threads=$optimalThreads, '
      'batch=$optimalBatchSize, ctx=$optimalContextSize, '
      'gpuLayers=$gpuLayers, timeout=${generationTimeoutSeconds}s)';
}

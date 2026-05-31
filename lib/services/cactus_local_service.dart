import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'cactus_worker.dart';
import 'cactus_ffi.dart' as cactus;

enum CactusAiError {
  none,
  modelNotFound,
  modelIncomplete,
  libraryUnavailable,
  loadFailed,
  generationFailed,
  generationTimeout,
  unknown,
}

class CactusAiResult {
  final String? text;
  final CactusAiError error;
  final String? message;
  final int tokensGenerated;
  final double timeToFirstTokenMs;
  final double totalTimeMs;

  const CactusAiResult({
    this.text,
    this.error = CactusAiError.none,
    this.message,
    this.tokensGenerated = 0,
    this.timeToFirstTokenMs = 0,
    this.totalTimeMs = 0,
  });

  bool get isSuccess => error == CactusAiError.none && text != null;
  bool get isError => error != CactusAiError.none;
}

class CactusModelConfig {
  final String id;
  final String displayName;
  final String sizeStr;
  final String repoId;
  final int sizeBytes;
  final String zipFilename;
  final String weightDirName;

  const CactusModelConfig({
    required this.id,
    required this.displayName,
    required this.sizeStr,
    required this.repoId,
    this.sizeBytes = 0,
    this.zipFilename = 'int4.zip',
    this.weightDirName = 'weights',
  });

  int get sizeMB => sizeBytes ~/ (1024 * 1024);

  String get downloadUrl =>
      'https://huggingface.co/$repoId/resolve/main/';

  String get zipUrl => '${downloadUrl}${weightDirName}/$zipFilename';

  String get configUrl => '${downloadUrl}config.json';
}

class CactusLocalService {
  static final CactusLocalService _instance =
      CactusLocalService._internal();
  factory CactusLocalService() => _instance;
  CactusLocalService._internal();

  final CactusWorker _worker = CactusWorker();
  bool _isInitialized = false;
  String? _currentModelId;
  bool _isGenerating = false;

  static const String defaultModelId = 'qwen3-0.6b';

  static const List<CactusModelConfig> availableModels = [
    CactusModelConfig(
      id: defaultModelId,
      displayName: 'Qwen3 (0.6B)',
      sizeStr: '~376 MB',
      repoId: 'Cactus-Compute/Qwen3-0.6B',
      sizeBytes: 394264576,
      zipFilename: 'qwen3-0.6b-int4.zip',
    ),
  ];

  bool get isInitialized => _isInitialized;
  bool get isGenerating => _isGenerating;
  bool get isNativeLibraryAvailable => true;

  CactusModelConfig getModelConfig(String id) {
    return availableModels.firstWhere(
      (m) => m.id == id,
      orElse: () => availableModels.first,
    );
  }

  Future<String> getModelPath(String modelId) async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/cactus/$modelId';
  }

  Future<bool> isModelDownloaded(String modelId) async {
    final path = await getModelPath(modelId);
    final dir = Directory(path);
    if (!await dir.exists()) return false;
    final entries = await dir.list().toList();
    var hasConfig = false;
    var hasWeights = false;
    for (final entry in entries) {
      if (entry is File) {
        if (entry.path.endsWith('config.json')) {
          hasConfig = true;
        } else {
          hasWeights = true;
        }
      }
    }
    if (!hasWeights) {
      final weightsDir = Directory('$path/weights');
      if (await weightsDir.exists()) {
        final wEntries = await weightsDir.list().toList();
        hasWeights = wEntries.any((e) => e is File);
      }
    }
    return hasConfig && hasWeights;
  }

  int getDownloadProgressPercentage(
      int received, int total) {
    if (total <= 0) return 0;
    return (received / total * 100).round();
  }

  Future<CactusAiResult> downloadModel(
    String modelId,
    void Function(int count, int total) onProgress, {
    CancelToken? cancelToken,
  }) async {
    final config = getModelConfig(modelId);
    final targetDir = await getModelPath(modelId);
    final tempDir = Directory('$targetDir.download');

    try {
      if (await Directory(targetDir).exists()) {
        await Directory(targetDir).delete(recursive: true);
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      await tempDir.create(recursive: true);

      final dio = Dio();

      // Step 1: Download config.json
      await dio.download(
        config.configUrl,
        '${tempDir.path}/config.json',
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      if (cancelToken?.isCancelled == true) {
        await tempDir.delete(recursive: true);
        return const CactusAiResult(
          error: CactusAiError.unknown,
          message: 'Download cancelled',
        );
      }
      onProgress(1, 3);

      // Step 2: Download the ZIP weights
      final zipPath = '${tempDir.path}/weights.zip';
      await dio.download(
        config.zipUrl,
        zipPath,
        onReceiveProgress: (received, total) {
          final steps = total > 0
              ? 1 + (received / total * 2).round()
              : 1;
          onProgress(steps.clamp(1, 3), 3);
        },
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
      if (cancelToken?.isCancelled == true) {
        await tempDir.delete(recursive: true);
        return const CactusAiResult(
          error: CactusAiError.unknown,
          message: 'Download cancelled',
        );
      }

      // Step 3: Extract the ZIP
      final zipFile = File(zipPath);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final entry in archive) {
        if (entry.isFile) {
          final outputPath = '${tempDir.path}/${entry.name}';
          final parentDir = Directory(
              outputPath.substring(0, outputPath.lastIndexOf('/')));
          if (!await parentDir.exists()) {
            await parentDir.create(recursive: true);
          }
          final outFile = File(outputPath);
          await outFile.writeAsBytes(entry.content);
        }
      }
      await zipFile.delete();
      onProgress(3, 3);

      // Move to final location
      final finalModelDir = Directory(targetDir);
      if (await finalModelDir.exists()) {
        await finalModelDir.delete(recursive: true);
      }
      await tempDir.rename(targetDir);

      return const CactusAiResult(text: 'ok');
    } on DioException catch (e) {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      if (e.type == DioExceptionType.cancel) {
        return const CactusAiResult(
          error: CactusAiError.unknown,
          message: 'Download cancelled',
        );
      }
      String msg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          msg = 'Connection timed out. Check your internet.';
          break;
        case DioExceptionType.connectionError:
          msg = 'No internet connection.';
          break;
        default:
          msg = 'Download error: ${e.message}';
      }
      return CactusAiResult(
        error: CactusAiError.unknown,
        message: msg,
      );
    } catch (e) {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      return CactusAiResult(
        error: CactusAiError.unknown,
        message: 'Download failed: $e',
      );
    }
  }

  bool _libraryCheck() {
    try {
      cactus.lastError();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CactusAiResult> initialize(String modelId) async {
    if (_isInitialized && _currentModelId == modelId) {
      return const CactusAiResult(text: 'ok');
    }

    try {
      await unloadModel();

      final path = await getModelPath(modelId);
      final dir = Directory(path);
      if (!await dir.exists()) {
        return CactusAiResult(
          error: CactusAiError.modelNotFound,
          message:
              'Model not found at $path. Download it from Settings.',
        );
      }

      final configFile = File('$path/config.json');
      if (!await configFile.exists()) {
        return CactusAiResult(
          error: CactusAiError.modelIncomplete,
          message: 'Model incomplete (no config.json). Re-download.',
        );
      }

      print('CactusLocalService: Initializing model $modelId '
          'from $path...');

      await _worker.start();
      final result = await _worker.init(path);
      if (result != 'ok') {
        return CactusAiResult(
          error: CactusAiError.loadFailed,
          message: result,
        );
      }

      _currentModelId = modelId;
      _isInitialized = true;
      print(
          'CactusLocalService: Model $modelId loaded successfully.');
      return const CactusAiResult(text: 'ok');
    } catch (e) {
      print('CactusLocalService: Init error: $e');
      return CactusAiResult(
        error: CactusAiError.loadFailed,
        message: 'Init failed: $e',
      );
    }
  }

  Future<CactusAiResult> generateText(
    String prompt, {
    String? systemPrompt,
    int maxTokens = 128,
    double temperature = 0.5,
  }) async {
    if (!_isInitialized) {
      return const CactusAiResult(
        error: CactusAiError.loadFailed,
        message: 'Model not loaded. Initialize first.',
      );
    }

    if (_isGenerating) {
      return const CactusAiResult(
        error: CactusAiError.generationFailed,
        message: 'Generation already in progress.',
      );
    }

    _isGenerating = true;

    try {
      final messages = [
        {
          'role': 'system',
          'content':
              systemPrompt ?? 'You are a JSON-only assistant.'
        },
        {'role': 'user', 'content': prompt},
      ];
      final messagesJson = jsonEncode(messages);

      final options = {
        'max_tokens': maxTokens,
        'temperature': temperature,
        'stop_sequences': [],
      };
      final optionsJson = jsonEncode(options);

      print(
          'CactusLocalService: Calling cactusComplete...');

      final responseJson = await _worker.generate(
          messagesJson, optionsJson);

      _isGenerating = false;

      if (responseJson.startsWith('error:')) {
        return CactusAiResult(
          error: CactusAiError.generationFailed,
          message: responseJson.substring(6),
        );
      }

      final parsed = jsonDecode(responseJson)
          as Map<String, dynamic>;

      if (parsed['success'] == true) {
        final response =
            (parsed['response'] as String?)?.trim() ?? '';
        if (response.isEmpty) {
          return const CactusAiResult(
            error: CactusAiError.generationFailed,
            message: 'Empty response from Cactus.',
          );
        }

        return CactusAiResult(
          text: response,
          tokensGenerated:
              (parsed['decode_tokens'] as int?) ?? 0,
          timeToFirstTokenMs:
              (parsed['time_to_first_token_ms'] as num?)?.toDouble() ??
                  0,
          totalTimeMs:
              (parsed['total_time_ms'] as num?)?.toDouble() ?? 0,
        );
      } else {
        return CactusAiResult(
          error: CactusAiError.generationFailed,
          message:
              (parsed['error'] as String?) ?? 'Generation failed',
        );
      }
    } on Exception catch (e) {
      _isGenerating = false;
      final msg = e.toString();
      if (msg.contains('timeout') || msg.contains('Timeout')) {
        return const CactusAiResult(
          error: CactusAiError.generationTimeout,
          message: 'Generation timed out.',
        );
      }
      return CactusAiResult(
        error: CactusAiError.generationFailed,
        message: 'Generation failed: $e',
      );
    } catch (e) {
      _isGenerating = false;
      return CactusAiResult(
        error: CactusAiError.unknown,
        message: 'Unexpected error: $e',
      );
    }
  }

  void cancelGeneration() {
    if (_isGenerating) {
      _worker.dispose();
      _isGenerating = false;
    }
  }

  Future<void> unloadModel() async {
    await _worker.dispose();
    _isInitialized = false;
    _currentModelId = null;
    _isGenerating = false;
    print('CactusLocalService: Model unloaded.');
  }

  Future<bool> deleteModel(String modelId) async {
    if (_currentModelId == modelId) await unloadModel();
    final path = await getModelPath(modelId);
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      return true;
    }
    return false;
  }

  Future<void> dispose() async {
    await unloadModel();
  }
}

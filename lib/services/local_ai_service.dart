import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'device_capability.dart';
import 'llama3_format.dart';
import 'word_summary_grammar.dart';

enum LocalAiError {
  none,
  modelNotFound,
  modelIncomplete,
  libraryUnavailable,
  loadFailed,
  generationFailed,
  generationTimeout,
  unknown,
}

class LocalAiResult {
  final String? text;
  final LocalAiError error;
  final String? message;

  const LocalAiResult(
      {this.text, this.error = LocalAiError.none, this.message});

  bool get isSuccess => error == LocalAiError.none && text != null;
  bool get isError => error != LocalAiError.none;
}

class LocalModelConfig {
  final String id;
  final String displayName;
  final String sizeStr;
  final String downloadUrl;
  final String filename;
  final int sizeBytes;

  const LocalModelConfig({
    required this.id,
    required this.displayName,
    required this.sizeStr,
    required this.downloadUrl,
    required this.filename,
    this.sizeBytes = 0,
  });

  int get sizeMB => sizeBytes ~/ (1024 * 1024);
}

typedef TokenCallback = void Function(String token, int count);

class LocalAIService {
  bool _isInitialized = false;
  String? _currentModelId;
  LlamaParent? _llamaParent;
  StreamSubscription<String>? _streamSub;
  Completer<void>? _initCompleter;
  TokenCallback? _onToken;

  static const List<LocalModelConfig> availableModels = [
    LocalModelConfig(
      id: 'smolm-135',
      displayName: 'SmolLM2 (135M) ⚡',
      sizeStr: '105 MB',
      filename: 'smolm2-135m-instruct-q4_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/bartowski/SmolLM2-135M-Instruct-GGUF/resolve/main/SmolLM2-135M-Instruct-Q4_K_M.gguf',
      sizeBytes: 110100480,
    ),
    LocalModelConfig(
      id: 'smolm-360',
      displayName: 'SmolLM2 (360M)',
      sizeStr: '280 MB',
      filename: 'smolm2-360m-instruct-q4_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf',
      sizeBytes: 293601280,
    ),
    LocalModelConfig(
      id: 'qwen',
      displayName: 'Qwen 2.5 (0.5B)',
      sizeStr: '432 MB',
      filename: 'qwen2.5-0.5b-instruct-q3_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q3_k_m.gguf',
      sizeBytes: 452984832,
    ),
    LocalModelConfig(
      id: 'qwen-hq',
      displayName: 'Qwen 2.5 (0.5B) HQ',
      sizeStr: '491 MB',
      filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
      sizeBytes: 515076096,
    ),
    LocalModelConfig(
      id: 'llama',
      displayName: 'Llama 3.2 (1B)',
      sizeStr: '730 MB',
      filename: 'llama-3.2-1b-instruct-q4_k_m.gguf',
      downloadUrl:
          'https://huggingface.co/hugging-quants/Llama-3.2-1B-Instruct-Q4_K_M-GGUF/resolve/main/llama-3.2-1b-instruct-q4_k_m.gguf',
      sizeBytes: 765460480,
    ),
  ];

  static final LocalAIService _instance = LocalAIService._internal();
  factory LocalAIService() => _instance;
  LocalAIService._internal();

  final DeviceCapability _device = DeviceCapability.instance;

  LocalModelConfig getModelConfig(String id) {
    return availableModels.firstWhere((m) => m.id == id,
        orElse: () => availableModels.first);
  }

  Future<String> getModelPath(String modelId) async {
    final directory = await getApplicationSupportDirectory();
    final modelDir = Directory('${directory.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    final config = getModelConfig(modelId);
    return '${modelDir.path}/${config.filename}';
  }

  Future<bool> isModelDownloaded(String modelId) async {
    final path = await getModelPath(modelId);
    final file = File(path);
    if (!await file.exists()) return false;
    final size = await file.length();
    return size > 100 * 1024 * 1024;
  }

  bool isModelSuitable(String modelId) {
    final config = getModelConfig(modelId);
    return _device.canRunModel(config.sizeMB);
  }

  String? getModelWarning(String modelId) {
    if (isModelSuitable(modelId)) return null;
    return 'This model (${getModelConfig(modelId).sizeStr}) may be too large '
        'for your device. Consider using a smaller model for best performance.';
  }

  static bool isNativeLibraryAvailable() {
    if (!Platform.isAndroid) return true;
    return true;
  }

  Future<LocalAiResult> downloadModel(
    String modelId,
    void Function(int count, int total) onReceiveProgress, {
    CancelToken? cancelToken,
  }) async {
    final config = getModelConfig(modelId);
    final path = await getModelPath(modelId);
    final dio = Dio();
    final tempPath = '$path.download';

    try {
      final targetFile = File(path);
      if (await targetFile.exists()) await targetFile.delete();
      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();

      await dio.download(
        config.downloadUrl,
        tempPath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      if (cancelToken?.isCancelled == true) {
        return const LocalAiResult(
          error: LocalAiError.unknown,
          message: 'Download cancelled',
        );
      }

      if (!await tempFile.exists()) {
        return const LocalAiResult(
          error: LocalAiError.unknown,
          message: 'Download failed: no file received',
        );
      }

      final downloadedSize = await tempFile.length();
      if (downloadedSize < 100 * 1024 * 1024) {
        await tempFile.delete();
        return LocalAiResult(
          error: LocalAiError.modelIncomplete,
          message:
              'Download incomplete (${(downloadedSize / 1048576).toStringAsFixed(1)} MB). Please try again.',
        );
      }

      await tempFile.rename(path);
      return const LocalAiResult(text: 'ok');
    } on DioException catch (e) {
      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();
      if (e.type == DioExceptionType.cancel) {
        return const LocalAiResult(
          error: LocalAiError.unknown,
          message: 'Download cancelled',
        );
      }
      String msg;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          msg = 'Connection timed out. Check your internet and try again.';
          break;
        case DioExceptionType.connectionError:
          msg = 'No internet connection. Connect to Wi-Fi or mobile data.';
          break;
        default:
          msg = 'Download error: ${e.message}';
      }
      return LocalAiResult(error: LocalAiError.unknown, message: msg);
    } catch (e) {
      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();
      return LocalAiResult(
          error: LocalAiError.unknown, message: 'Unexpected error: $e');
    }
  }

  Future<List<(LocalModelConfig, int)>> getDownloadedModels() async {
    final directory = await getApplicationSupportDirectory();
    final modelDir = Directory('${directory.path}/models');
    if (!await modelDir.exists()) return [];

    final result = <(LocalModelConfig, int)>[];
    for (final config in availableModels) {
      final file = File('${modelDir.path}/${config.filename}');
      if (await file.exists()) {
        final size = await file.length();
        if (size > 100 * 1024 * 1024) {
          result.add((config, size));
        }
      }
    }
    return result;
  }

  Future<bool> deleteModel(String modelId) async {
    if (_currentModelId == modelId) await unloadModel();
    final path = await getModelPath(modelId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  Future<int> getTotalStorageUsed() async {
    final models = await getDownloadedModels();
    return models.fold<int>(0, (sum, m) => sum + m.$2);
  }

  bool get isGenerating => _isGenerating;

  bool _isGenerating = false;

  void cancelGeneration() {
    if (_llamaParent != null && _isGenerating) {
      _llamaParent!.stop();
    }
    _isGenerating = false;
  }

  void setTokenCallback(TokenCallback? callback) {
    _onToken = callback;
  }

  PromptFormat? _getFormatterForModel(String modelId) {
    switch (modelId) {
      case 'smolm-135':
      case 'smolm-360':
      case 'qwen':
      case 'qwen-hq':
        return ChatMLFormat();
      case 'llama':
        return Llama3Format();
      default:
        return ChatMLFormat();
    }
  }

  Future<LocalAiResult> initialize(String modelId) async {
    if (_initCompleter != null) await _initCompleter!.future;

    if (_isInitialized && _currentModelId == modelId && _llamaParent != null) {
      return const LocalAiResult(text: 'ok');
    }

    _initCompleter = Completer<void>();
    try {
      if (!isNativeLibraryAvailable()) {
        return const LocalAiResult(
          error: LocalAiError.libraryUnavailable,
          message: 'Native Llama library not available in this build.',
        );
      }

      final path = await getModelPath(modelId);
      final file = File(path);
      if (!await file.exists()) {
        return LocalAiResult(
          error: LocalAiError.modelNotFound,
          message: 'Model file not found at $path. Download it from Settings.',
        );
      }

      final size = await file.length();
      if (size < 100 * 1024 * 1024) {
        return LocalAiResult(
          error: LocalAiError.modelIncomplete,
          message:
              'Model file is incomplete (${(size / 1048576).toStringAsFixed(1)} MB). Delete and re-download.',
        );
      }

      if (_currentModelId != modelId) {
        await unloadModel();
      }

      final formatter = _getFormatterForModel(modelId)!;
      final parent = await _loadModel(modelId, formatter);

      if (parent == null) {
        return const LocalAiResult(
          error: LocalAiError.loadFailed,
          message: 'Failed to load model.',
        );
      }

      print(
          'LocalAIService: Model $modelId loaded on ${_device.tier.name} device '
          '(threads=${_device.optimalThreads}, ctx=${_device.optimalContextSize}, '
          'gpuLayers=${_device.gpuLayers}).');
      return const LocalAiResult(text: 'ok');
    } catch (e) {
      _llamaParent = null;
      _isInitialized = false;
      _currentModelId = null;
      print('LocalAIService: Failed to load model: $e');
      return LocalAiResult(
        error: LocalAiError.loadFailed,
        message: 'Failed to load model: $e',
      );
    } finally {
      _initCompleter!.complete();
      _initCompleter = null;
    }
  }

  bool get isInitialized => _isInitialized;

  Duration get _generationTimeout =>
      Duration(seconds: _device.generationTimeoutSeconds);

  Future<LocalAiResult> generateText(String prompt,
      {String? systemPrompt, bool keepAlive = false}) async {
    if (_currentModelId == null) {
      return const LocalAiResult(
        error: LocalAiError.loadFailed,
        message: 'Model not loaded. Initialize first.',
      );
    }

    if (_isGenerating) {
      return const LocalAiResult(
        error: LocalAiError.generationFailed,
        message: 'Generation already in progress.',
      );
    }

    _isGenerating = true;
    final modelId = _currentModelId!;
    final formatter = _getFormatterForModel(modelId)!;
    final buffer = StringBuffer();

    LlamaParent? parent = _llamaParent;
    StreamSubscription<String>? sub;
    String? promptId;
    bool needsReload = (parent == null);

    try {
      if (needsReload) {
        parent = await _loadModel(modelId, formatter);
        if (parent == null) {
          _isGenerating = false;
          return const LocalAiResult(
            error: LocalAiError.loadFailed,
            message: 'Failed to load model.',
          );
        }
      }

      parent.messages.clear();
      parent.messages.add({
        'role': 'system',
        'content': systemPrompt ?? 'Respond with valid JSON only.'
      });
      parent.messages.add({'role': 'user', 'content': prompt});

      final formattedPrompt = formatter.formatMessages(parent.messages);
      print(
          'LocalAIService: Formatted prompt (${formattedPrompt.length} chars): ${formattedPrompt.substring(0, formattedPrompt.length > 150 ? 150 : formattedPrompt.length)}...');

      int tokenCount = 0;
      sub = parent.stream.listen((token) {
        tokenCount++;
        buffer.write(token);
        _onToken?.call(token, tokenCount);
      });

      promptId = await parent.sendPrompt(prompt);
      print('LocalAIService: Prompt sent, promptId=$promptId');

      final completion = await parent.completions
          .firstWhere((e) => e.promptId == promptId)
          .timeout(
        _generationTimeout,
        onTimeout: () {
          print(
              'LocalAIService: Generation timed out after ${_generationTimeout.inSeconds}s, $tokenCount tokens. Parent will be disposed on failure path.');
          return CompletionEvent(promptId!, false, 'Generation timed out');
        },
      );

      await sub.cancel();
      sub = null;

      _isGenerating = false;

      print(
          'LocalAIService: Generation complete. success=${completion.success} tokens=$tokenCount');

      if (tokenCount == 0 && completion.success == true) {
        print(
            'LocalAIService: 0 tokens with success=true, context likely stale. Reloading model...');
        await _unloadParent(parent);
        parent = await _loadModel(modelId, formatter);
        if (parent == null) {
          return const LocalAiResult(
            error: LocalAiError.loadFailed,
            message: 'Failed to reload model.',
          );
        }
        return _generateWithParent(
            parent, prompt, systemPrompt, modelId, formatter);
      }

      if (completion.success == false) {
        final errMsg = completion.errorDetails ?? 'Generation failed';
        print('LocalAIService: Generation failed: $errMsg');
        await _unloadParent(parent);
        return LocalAiResult(
          error: LocalAiError.generationFailed,
          message: errMsg,
        );
      }

      final result = buffer.toString().trim();
      if (result.isEmpty) {
        print('LocalAIService: Empty result despite $tokenCount tokens');
        await _unloadParent(parent);
        return const LocalAiResult(
          error: LocalAiError.generationFailed,
          message: 'Local model returned empty response.',
        );
      }

      print(
          'LocalAIService: Generated ${result.length} chars, $tokenCount tokens');
      if (!keepAlive) {
        _llamaParent = parent;
      }
      return LocalAiResult(text: result);
    } on TimeoutException {
      _isGenerating = false;
      await sub?.cancel();
      await _unloadParent(_llamaParent);
      print('LocalAIService: Generation timed out');
      return LocalAiResult(
        error: LocalAiError.generationTimeout,
        message: 'Generation timed out. Try again or use a cloud provider.',
      );
    } on LlamaException catch (e) {
      _isGenerating = false;
      await sub?.cancel();
      await _unloadParent(_llamaParent);
      print('LocalAIService: Llama error: $e');
      return LocalAiResult(
        error: LocalAiError.generationFailed,
        message: 'Generation failed: $e',
      );
    } catch (e) {
      _isGenerating = false;
      await sub?.cancel();
      await _unloadParent(_llamaParent);
      print('LocalAIService: Generation error: $e');
      return LocalAiResult(
        error: LocalAiError.generationFailed,
        message: 'Generation failed: $e',
      );
    }
  }

  Future<LocalAiResult> _generateWithParent(
    LlamaParent parent,
    String prompt,
    String? systemPrompt,
    String modelId,
    PromptFormat formatter,
  ) async {
    final buffer = StringBuffer();
    StreamSubscription<String>? sub;
    String? promptId;

    try {
      parent.messages.clear();
      parent.messages.add({
        'role': 'system',
        'content': systemPrompt ?? 'Respond with valid JSON only.'
      });
      parent.messages.add({'role': 'user', 'content': prompt});

      int tokenCount = 0;
      sub = parent.stream.listen((token) {
        tokenCount++;
        buffer.write(token);
        _onToken?.call(token, tokenCount);
      });

      promptId = await parent.sendPrompt(prompt);

      final completion = await parent.completions
          .firstWhere((e) => e.promptId == promptId)
          .timeout(
        _generationTimeout,
        onTimeout: () {
          parent.stop();
          return CompletionEvent(promptId!, false, 'Generation timed out');
        },
      );

      await sub.cancel();
      _isGenerating = false;

      if (completion.success == false) {
        final errMsg = completion.errorDetails ?? 'Generation failed';
        return LocalAiResult(
          error: LocalAiError.generationFailed,
          message: errMsg,
        );
      }

      final result = buffer.toString().trim();
      if (result.isEmpty) {
        return const LocalAiResult(
          error: LocalAiError.generationFailed,
          message: 'Local model returned empty response.',
        );
      }

      print(
          'LocalAIService: Retry generated ${result.length} chars, $tokenCount tokens');
      return LocalAiResult(text: result);
    } catch (e) {
      _isGenerating = false;
      await sub?.cancel();
      await _unloadParent(_llamaParent);
      print('LocalAIService: Retry generation error: $e');
      return LocalAiResult(
        error: LocalAiError.generationFailed,
        message: 'Generation failed: $e',
      );
    }
  }

  Future<LlamaParent?> _loadModel(
      String modelId, PromptFormat formatter) async {
    try {
      final path = await getModelPath(modelId);
      final file = File(path);
      if (!await file.exists()) return null;

      if (Platform.isAndroid) {
        Llama.libraryPath = "libmtmd.so";
      } else if (Platform.isWindows) {
        Llama.libraryPath = "llama.dll";
      } else if (Platform.isLinux) {
        Llama.libraryPath = "libllama.so";
      }

      final device = _device;
      final threads = device.optimalThreads;
      final batchSize = device.optimalBatchSize;
      final ctxSize = device.optimalContextSize;
      final maxTokens = device.optimalMaxTokens;
      final gpuLayers = device.gpuLayers;

      print('LocalAIService: Device tier=${device.tier.name}, '
          'cores=${device.cpuCores}, mem=${device.totalMemoryMB}MB, '
          'config: threads=$threads, batch=$batchSize, ctx=$ctxSize, '
          'maxTokens=$maxTokens, gpuLayers=$gpuLayers');

      final modelParams = ModelParams();
      modelParams.nGpuLayers = gpuLayers;
      modelParams.mainGpu = gpuLayers > 0 ? 0 : -1;
      modelParams.useMemorymap = true;

      final contextParams = ContextParams()
        ..nCtx = ctxSize
        ..nPredict = maxTokens
        ..nBatch = batchSize
        ..nUbatch = batchSize
        ..nThreads = threads
        ..nThreadsBatch = threads;

      if (device.shouldQuantizeKvCache) {
        contextParams.typeK = LlamaKvCacheType.q4_0;
        contextParams.typeV = LlamaKvCacheType.q4_0;
      }

      final samplingParams = SamplerParams()
        ..temp = 0.0
        ..penaltyRepeat = 1.05
        ..greedy = true
        ..grammarStr = wordSummaryGrammar
        ..grammarRoot = 'root';

      final loadCommand = LlamaLoad(
        path: path,
        modelParams: modelParams,
        contextParams: contextParams,
        samplingParams: samplingParams,
        verbose: false,
      );

      final parent = LlamaParent(loadCommand, formatter);

      await parent.init().timeout(
        Duration(seconds: 120),
        onTimeout: () {
          throw TimeoutException('Model loading timed out after 120s');
        },
      );

      _llamaParent = parent;
      _isInitialized = true;
      _currentModelId = modelId;
      print('LocalAIService: Model $modelId loaded successfully '
          'on ${Platform.isAndroid ? "Android" : "desktop"} '
          '(threads=$threads, kv=${device.shouldQuantizeKvCache ? "q4_0" : "f16"}).');
      return parent;
    } catch (e) {
      print('LocalAIService: Model load error: $e');
      _llamaParent = null;
      _isInitialized = false;
      return null;
    }
  }

  Future<void> _unloadParent(LlamaParent? parent) async {
    _llamaParent = null;
    _isInitialized = false;
    _currentModelId = null;
    if (parent != null) {
      try {
        await parent.dispose().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('LocalAIService: Dispose timed out, forcing cleanup.');
          },
        );
      } catch (e) {
        print('LocalAIService: Dispose error: $e');
      }
    }
  }

  Future<void> unloadModel() async {
    await _streamSub?.cancel();
    _streamSub = null;
    if (_llamaParent != null) {
      try {
        await _llamaParent!.dispose();
      } catch (e) {
        print('LocalAIService: Dispose error: $e');
      }
      _llamaParent = null;
    }
    _isInitialized = false;
    _currentModelId = null;
    _isGenerating = false;
    print('LocalAIService: Model unloaded.');
  }

  Future<void> dispose() async {
    await unloadModel();
  }
}

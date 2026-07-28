import 'dart:async';

import 'package:llama_cpp_dart/llama_cpp_dart.dart' hide Message;
import '../models/message.dart';
import '../models/model_config.dart';
import 'memory_service.dart';

// =============================================================================
// 抽象 LLM 服务接口（保持兼容）
// =============================================================================

abstract class LlmService {
  bool get isModelLoaded;
  ModelConfig? get currentConfig;
  Future<void> loadModel(ModelConfig config);
  Future<void> unloadModel();
  Future<String> generate(String prompt, {List<Message>? history, int maxTokens, double? temperature, double? topP});
  Stream<String> streamGenerate(String prompt, {List<Message>? history, int maxTokens, double? temperature, double? topP});
  Stream<String> generateWithTools(String prompt, {List<Message>? history, List<Map<String, dynamic>>? tools, int maxTokens, double? temperature, double? topP});
  void stop();
}

// =============================================================================
// llama.cpp 后端 — 编译的 libllama.so + dart FFI
// =============================================================================

class LlamaCppService implements LlmService {
  @override
  bool isModelLoaded = false;

  @override
  ModelConfig? currentConfig;

  LlamaParent? _llamaParent;
  StreamSubscription? _subscription;
  bool _stopRequested = false;

  /// 记忆服务
  final MemoryService? memoryService;

  LlamaCppService({this.memoryService});

  static const String _libName = 'libllama.so';

  // ---------------------------------------------------------------------------
  // 模型加载 / 卸载
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadModel(ModelConfig config) async {
    if (isModelLoaded) await unloadModel();

    _stopRequested = false;

    // 模型文件路径（用户下载后存在应用目录下）
    final modelPath = config.filePath;

    // 设置 .so 路径
    Llama.libraryPath = _libName;

    final modelParams = ModelParams()
      ..nGpuLayers = -1; // 自动 GPU 加速
    final contextParams = ContextParams()
      ..nCtx = config.contextSize;
    final samplerParams = SamplerParams()
      ..temp = config.temperature
      ..topP = config.topP;

    final loadCommand = LlamaLoad(
      path: modelPath,
      modelParams: modelParams,
      contextParams: contextParams,
      samplingParams: samplerParams,
    );

    try {
      _llamaParent = LlamaParent(loadCommand, ChatMLFormat());
      await _llamaParent!.init();
      isModelLoaded = true;
      currentConfig = config;
    } catch (e) {
      isModelLoaded = false;
      _llamaParent = null;
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    _stopRequested = true;
    await _subscription?.cancel();
    _llamaParent?.dispose();
    _llamaParent = null;
    isModelLoaded = false;
    currentConfig = null;
  }

  // ---------------------------------------------------------------------------
  // 生成（非流式）
  // ---------------------------------------------------------------------------

  @override
  Future<String> generate(
    String prompt, {
    List<Message>? history,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) async {
    if (_llamaParent == null) return '⚠️ 模型未加载';

    _stopRequested = false;
    final output = StringBuffer();
    final completer = Completer<String>();

    _subscription = _llamaParent!.stream.listen(
      (response) {
        if (_stopRequested) {
          completer.complete(output.toString());
          return;
        }
        output.write(response);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(output.toString());
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.complete('⚠️ 推理出错: $e');
        }
      },
    );

    _llamaParent!.sendPrompt(prompt);
    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // 流式生成
  // ---------------------------------------------------------------------------

  @override
  Stream<String> streamGenerate(
    String prompt, {
    List<Message>? history,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) {
    return _createStream(prompt);
  }

  @override
  Stream<String> generateWithTools(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) {
    return _createStream(prompt);
  }

  @override
  void stop() {
    _stopRequested = true;
    _subscription?.cancel();
  }

  // ---------------------------------------------------------------------------
  // 核心流式
  // ---------------------------------------------------------------------------

  Stream<String> _createStream(String prompt) async* {
    if (_llamaParent == null) {
      yield '⚠️ 模型未加载';
      return;
    }

    _stopRequested = false;
    final output = StringBuffer();

    _subscription = _llamaParent!.stream.listen(
      (response) {
        output.write(response);
      },
      onDone: () {},
      onError: (e) {
        output.write('\n\n⚠️ 推理出错: $e');
      },
    );

    _llamaParent!.sendPrompt(prompt);

    // 轮询输出
    while (!_stopRequested) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (output.isNotEmpty) {
        final text = output.toString();
        output.clear();
        yield text;
      }
    }
  }
}

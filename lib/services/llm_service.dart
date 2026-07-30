import 'dart:async';
import 'dart:io' as io;

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

    // 检查模型文件是否存在
    final file = io.File(config.filePath);
    if (!file.existsSync()) {
      throw LlamaException(
        '模型文件不存在: ${config.filePath}\n\n'
        '推荐模型需要先下载 .gguf 文件到设备上。请使用「从本地选择 .gguf 模型文件」'
        '功能选择已下载的模型文件。如需下载推荐模型，请使用联网搜索找到下载链接。',
      );
    }

    // 检查文件大小是否合理（GGUF 最小几 MB）
    if (file.lengthSync() < 1024 * 1024) {
      throw LlamaException(
        '模型文件异常: ${config.filePath} (仅 ${file.lengthSync()} 字节)\n'
        '文件可能损坏或不完整，请重新下载。',
      );
    }

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
      path: config.filePath,
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
      // 提取原生错误中的有用信息，不要抛原生异常
      final errMsg = e.toString();
      if (errMsg.contains('failed to load model') || 
          errMsg.contains('gguf') ||
          errMsg.contains('GGML')) {
        throw LlamaException(
          '模型加载失败: 文件可能损坏或不兼容\n'
          '请检查 .gguf 文件是否完整，或尝试使用其他量化版本。',
        );
      }
      throw LlamaException('模型加载失败: $errMsg');
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

/// llama.cpp 相关异常
class LlamaException implements Exception {
  final String message;
  const LlamaException(this.message);

  @override
  String toString() => message;
}

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

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
  Future<String> generate(String prompt,
      {List<Message>? history,
      int maxTokens,
      double? temperature,
      double? topP});
  Stream<String> streamGenerate(String prompt,
      {List<Message>? history,
      int maxTokens,
      double? temperature,
      double? topP});
  Stream<String> generateWithTools(String prompt,
      {List<Message>? history,
      List<Map<String, dynamic>>? tools,
      int maxTokens,
      double? temperature,
      double? topP});
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

  /// 模型加载超时（秒）
  static const int _modelLoadTimeoutSeconds = 30;

  // ---------------------------------------------------------------------------
  // GGUF 文件头校验
  // ---------------------------------------------------------------------------

  /// GGUF 文件魔数（4 字节）
  static final Uint8List _ggufMagic = Uint8List.fromList([0x47, 0x47, 0x55, 0x46]); // "GGUF"

  /// 校验文件是否为合法的 GGUF 格式
  ///
  /// 会在加载前快速读取文件头 4 字节，确保是 GGUF 格式。
  /// 如无法打开或魔数不匹配，抛出 [LlamaException]。
  static void validateGgufFile(String filePath) {
    try {
      final file = io.File(filePath);
      final raf = file.openSync(mode: io.FileMode.read);
      try {
        final header = raf.readSync(4);
        if (header.length < 4 || !_listEquals(header, _ggufMagic)) {
          throw LlamaException(
            '文件不是合法的 GGUF 格式（文件头 4 字节应为 GGUF）。\n'
            '请确认选择的是正确的 .gguf 模型文件。',
          );
        }
      } finally {
        raf.closeSync();
      }
    } on io.FileSystemException catch (e) {
      throw LlamaException('无法读取模型文件: $e');
    }
  }

  /// 字节列表相等比较
  static bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

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

    // 检查文件大小（GGUF 最少几 MB）
    final fileSize = file.lengthSync();
    if (fileSize < 1024 * 1024) {
      throw LlamaException(
        '模型文件异常: ${config.filePath} (仅 $fileSize 字节)\n'
        '文件可能损坏或不完整，请重新下载。',
      );
    }

    // GGUF 文件头校验
    validateGgufFile(config.filePath);

    // 内存预估估算
    final estimatedMemMB = fileSize ~/ (1024 * 1024) * 2; // 约文件大小的 2 倍
    if (estimatedMemMB > 14000) {
      throw LlamaException(
        '模型可能需要约 $estimatedMemMB MB 内存（文件 ${fileSize ~/ (1024 * 1024)} MB x 2），'
        '超过大部分设备可用内存。建议使用更小量化的版本。',
      );
    }

    // 设置 .so 路径
    Llama.libraryPath = _libName;

    final modelParams = ModelParams()
      ..nGpuLayers = 0; // 先设 0（纯 CPU 加载），后续可改
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

    _llamaParent = LlamaParent(loadCommand, ChatMLFormat());

    // 将 init() 放在单独的函数中，用超时保护
    try {
      await _initWithTimeout();
      isModelLoaded = true;
      currentConfig = config;
    } catch (e) {
      // 清理残留状态
      isModelLoaded = false;
      try {
        _llamaParent?.dispose();
      } catch (_) {}
      _llamaParent = null;

      final errMsg = e.toString();
      if (errMsg.contains('timed out') || errMsg.contains('Timeout')) {
        throw LlamaException(
          '模型加载超时（${_modelLoadTimeoutSeconds}秒）。\n'
          '可能是文件过大或设备内存不足。建议使用更小量化的模型。',
        );
      }
      throw LlamaException('模型加载失败: $errMsg');
    }
  }

  /// 带超时的初始化
  Future<void> _initWithTimeout() async {
    final completer = Completer<void>();

    // 在下一个微任务中启动加载，确保超时计时器能先注册
    Future.microtask(() async {
      try {
        await _llamaParent!.init();
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    // 超时保护
    final timeout = Future.delayed(
      Duration(seconds: _modelLoadTimeoutSeconds),
      () {
        if (!completer.isCompleted) {
          // 超时了 —— 强制清理
          completer.completeError(
            TimeoutException('模型加载超时（${_modelLoadTimeoutSeconds}秒）'),
          );
        }
      },
    );

    await Future.any([completer.future, timeout]);
  }

  @override
  Future<void> unloadModel() async {
    _stopRequested = true;
    await _subscription?.cancel();
    _subscription = null;
    try {
      _llamaParent?.dispose();
    } catch (_) {}
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

import 'dart:async';

import 'package:llamadart/llamadart.dart';
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
// llamadart 后端 — 完全本地推理，无需 Termux / Ollama
// =============================================================================

class LlamaDartService implements LlmService {
  @override
  bool isModelLoaded = false;

  @override
  ModelConfig? currentConfig;

  LlamaEngine? _engine;
  bool _stopRequested = false;

  /// 记忆服务（可选，用于注入对话上下文）
  final MemoryService? memoryService;

  /// 下载进度回调（用于 UI 显示）
  final void Function(double progress)? onDownloadProgress;

  LlamaDartService({this.memoryService, this.onDownloadProgress});

  /// 默认模型源（HuggingFace GGUF）
  static const String defaultModelSource =
      'hf://Qwen/Qwen2.5-1.5B-Instruct-GGUF/qwen2.5-1.5b-instruct-q4_k_m.gguf';

  // ---------------------------------------------------------------------------
  // 模型加载 / 卸载
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadModel(ModelConfig config) async {
    if (isModelLoaded) await unloadModel();

    _stopRequested = false;

    // 确定模型源
    final modelSource = config.filePath.isNotEmpty
        ? config.filePath  // 本地文件路径或 HF URL
        : defaultModelSource;

    // 初始化 llamadart 引擎
    final backend = LlamaBackend();
    _engine = LlamaEngine(backend);

    try {
      await _engine!.loadModelSource(
        ModelSource.parse(modelSource),
        params: ModelParams(
          contextSize: config.contextSize,
          gpuLayers: -1, // 自动 GPU 加速
        ),
      );
      isModelLoaded = true;
      currentConfig = config;
    } catch (e) {
      isModelLoaded = false;
      _engine = null;
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    _stopRequested = true;
    await _engine?.dispose();
    _engine = null;
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
    if (_engine == null) return '⚠️ 模型未加载';

    final messages = await _buildMessages(prompt, history: history);
    final output = StringBuffer();

    try {
      await for (final chunk in _engine!.create(
        messages,
        params: GenerationParams(
          maxTokens: maxTokens,
          temperature: temperature ?? 0.7,
          topP: topP ?? 0.9,
        ),
      )) {
        if (_stopRequested) break;
        final text = chunk.choices.first.delta.content;
        if (text != null) {
          output.write(text);
        }
      }
    } catch (e) {
      return '⚠️ 推理出错: $e';
    }

    if (_stopRequested) return '';
    return output.toString();
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
    return _createStream(
      prompt,
      history: history,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: topP,
    );
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
    return _createStream(
      prompt,
      history: history,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: topP,
    );
  }

  @override
  void stop() {
    _stopRequested = true;
    // llamadart 通过 dispose 停止，但这里我们只是标记
  }

  // ---------------------------------------------------------------------------
  // 核心流式方法
  // ---------------------------------------------------------------------------

  Stream<String> _createStream(
    String prompt, {
    List<Message>? history,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) async* {
    if (_engine == null) {
      yield '⚠️ 模型未加载';
      return;
    }

    _stopRequested = false;
    final messages = await _buildMessages(prompt, history: history);

    try {
      await for (final chunk in _engine!.create(
        messages,
        params: GenerationParams(
          maxTokens: maxTokens,
          temperature: temperature ?? 0.7,
          topP: topP ?? 0.9,
        ),
      )) {
        if (_stopRequested) break;
        final text = chunk.choices.first.delta.content;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } catch (e) {
      yield '\n\n⚠️ 推理出错: $e\n\n'
          '可能是模型下载未完成或内存不足。\n'
          '请确认手机至少有 2GB 可用内存。';
    }
  }

  // ---------------------------------------------------------------------------
  // 构建消息历史
  // ---------------------------------------------------------------------------

  Future<List<LlamaChatMessage>> _buildMessages(
    String prompt, {
    List<Message>? history,
  }) async {
    final messages = <LlamaChatMessage>[];

    // 拼接记忆上下文
    String memoryContext = '';
    try {
      if (memoryService != null) {
        memoryContext = await memoryService!.buildMemoryContext(prompt);
      }
    } catch (_) {}

    // 系统提示
    String systemPrompt = '你是一个有帮助的AI助手，运行在本地设备上。'
        '请用中文回复，回答简洁准确。';
    if (memoryContext.isNotEmpty) {
      systemPrompt += '\n\n以下是我对你的了解：$memoryContext';
    }

    messages.add(LlamaChatMessage(
      role: LlamaChatRole.system,
      content: systemPrompt,
    ));

    // 历史消息
    if (history != null) {
      for (final msg in history) {
        LlamaChatRole role;
        switch (msg.role) {
          case MessageRole.user:
            role = LlamaChatRole.user;
            break;
          case MessageRole.assistant:
            role = LlamaChatRole.assistant;
            break;
          default:
            continue;
        }
        messages.add(LlamaChatMessage(role: role, content: msg.content));
      }
    }

    // 当前用户输入
    messages.add(LlamaChatMessage(
      role: LlamaChatRole.user,
      content: prompt,
    ));

    return messages;
  }
}

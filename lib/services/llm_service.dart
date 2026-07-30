import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';
import '../models/message.dart';
import '../models/model_config.dart';

// =============================================================================
// 抽象 LLM 服务接口（保持不变，方便切换后端）
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
  Future<String> generateWithFunctionCalling(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
    int maxTokens,
    double? temperature,
    double? topP,
  });
  Stream<String> streamGenerateWithFunctionCalling(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
    int maxTokens,
    double? temperature,
    double? topP,
  });
  void stop();
}

// =============================================================================
// FlutterGemma 后端
// =============================================================================

/// 基于 flutter_gemma 的 LLM 服务实现。
///
/// flutter_gemma 使用 Android 原生 LiteRT-LM 引擎（Platform Channel），
/// 不走 dart:ffi，不会出现 FFI 闪退问题。
/// 支持多种模型（Gemma、Qwen、Phi-4、DeepSeek 等 .litertlm 格式）。
class FlutterGemmaService implements LlmService {
  @override
  bool isModelLoaded = false;

  @override
  ModelConfig? currentConfig;

  /// flutter_gemma 的 InferenceModel 实例
  InferenceModel? _model;

  /// flutter_gemma 的 Chat 实例
  Chat? _chat;

  /// 停止标志
  bool _stopRequested = false;

  /// 当前正在发送的消息 complation
  Completer<void>? _currentGeneration;

  FlutterGemmaService();

  // ---------------------------------------------------------------------------
  // 加载模型
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadModel(ModelConfig config) async {
    if (isModelLoaded) await unloadModel();

    _stopRequested = false;

    try {
      // 使用 flutter_gemma 获取/激活模型
      _model = await FlutterGemma.getActiveModel(
        maxTokens: config.maxTokens,
        preferredBackend: PreferredBackend.gpu, // 优先 GPU 加速
      );

      // 创建 Chat 会话（支持流式输出）
      _chat = await _model!.createChat(
        temperature: config.temperature,
        randomSeed: 1,
        topK: 40,
        topP: config.topP,
        tokenBuffer: 256,
      );

      isModelLoaded = true;
      currentConfig = config;
    } catch (e) {
      isModelLoaded = false;
      _model = null;
      _chat = null;
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    _stopRequested = true;
    _currentGeneration = null;
    try {
      await _chat?.close();
    } catch (_) {}
    try {
      await _model?.close();
    } catch (_) {}
    _chat = null;
    _model = null;
    isModelLoaded = false;
    currentConfig = null;
  }

  // ---------------------------------------------------------------------------
  // 非流式生成
  // ---------------------------------------------------------------------------

  @override
  Future<String> generate(
    String prompt, {
    List<Message>? history,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) async {
    if (_chat == null) return '⚠️ 模型未加载';

    _stopRequested = false;
    try {
      final response = await _chat!.sendMessage(prompt);
      return response.text;
    } catch (e) {
      return '⚠️ 生成出错: $e';
    }
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
  }) async* {
    if (_chat == null) {
      yield '⚠️ 模型未加载';
      return;
    }

    _stopRequested = false;
    final completer = Completer<void>();
    _currentGeneration = completer;

    try {
      await for (final event in _chat!.sendMessageStream(prompt)) {
        if (_stopRequested) break;

        switch (event) {
          case ChatEvent.textEvent(:final text):
            yield text;
          case ChatEvent.toolCallEvent():
            // 函数调用事件（没有函数注册时由回调处理）
            break;
        }
      }
    } catch (e) {
      yield '\n\n⚠️ 流式生成出错: $e';
    } finally {
      if (!completer.isCompleted) completer.complete();
    }

    _currentGeneration = null;
  }

  // ---------------------------------------------------------------------------
  // 带函数调用的生成
  // ---------------------------------------------------------------------------

  @override
  Future<String> generateWithFunctionCalling(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) async {
    if (_chat == null) return '⚠️ 模型未加载';

    _stopRequested = false;
    try {
      final response = await _chat!.sendMessage(prompt);
      return response.text;
    } catch (e) {
      return '⚠️ 生成出错: $e';
    }
  }

  @override
  Stream<String> streamGenerateWithFunctionCalling(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) async* {
    if (_chat == null) {
      yield '⚠️ 模型未加载';
      return;
    }

    _stopRequested = false;
    _currentGeneration = Completer<void>();

    try {
      await for (final event in _chat!.sendMessageStream(prompt)) {
        if (_stopRequested) break;

        if (event case ChatEvent.textEvent(:final text)) {
          yield text;
        }
      }
    } catch (e) {
      yield '\n\n⚠️ 出错: $e';
    } finally {
      _currentGeneration?.complete();
      _currentGeneration = null;
    }
  }

  // ---------------------------------------------------------------------------
  // 停止
  // ---------------------------------------------------------------------------

  @override
  void stop() {
    _stopRequested = true;
    // flutter_gemma 的 Chat 没有中断方法，但可以在事件循环中退出
  }
}

/// 模型加载异常
class ModelLoadException implements Exception {
  final String message;
  const ModelLoadException(this.message);

  @override
  String toString() => message;
}

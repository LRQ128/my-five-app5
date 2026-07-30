import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart'
    hide Message; // 冲突：flutter_gemma 也有 Message 类

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
  InferenceChat? _chat;

  /// 停止标志
  bool _stopRequested = false;

  FlutterGemmaService();

  // ---------------------------------------------------------------------------
  // 加载模型
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadModel(ModelConfig config) async {
    if (isModelLoaded) await unloadModel();

    _stopRequested = false;

    try {
      // 获取/激活已安装的模型
      _model = await FlutterGemma.getActiveModel(maxTokens: config.maxTokens);

      // 创建 Chat 会话
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

    try {
      await for (final event in _chat!.sendMessageStream(prompt)) {
        if (_stopRequested) break;

        if (event case ChatEvent.textEvent(:final text)) {
          yield text;
        }
      }
    } catch (e) {
      yield '\n\n⚠️ 流式生成出错: $e';
    }
  }

  // ---------------------------------------------------------------------------
  // 停止
  // ---------------------------------------------------------------------------

  @override
  void stop() {
    _stopRequested = true;
  }
}

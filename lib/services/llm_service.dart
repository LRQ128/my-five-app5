import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart'
    hide Message; // flutter_gemma 的 Message 与我们的冲突
import 'package:flutter_gemma/core/message.dart' as gemma_msg;

import '../models/message.dart';
import '../models/model_config.dart';

// =============================================================================
// 抽象 LLM 服务接口
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
/// 使用 Android 原生引擎（Platform Channel），不走 dart:ffi，不会闪退。
class FlutterGemmaService implements LlmService {
  @override
  bool isModelLoaded = false;

  @override
  ModelConfig? currentConfig;

  InferenceModel? _model;
  InferenceChat? _chat;
  bool _stopRequested = false;

  FlutterGemmaService();

  @override
  Future<void> loadModel(ModelConfig config) async {
    if (isModelLoaded) await unloadModel();
    _stopRequested = false;

    try {
      _model = await FlutterGemma.getActiveModel(maxTokens: config.maxTokens);
      _chat = await _model!.createChat(
        temperature: config.temperature,
        randomSeed: 1,
        topK: 40,
        topP: config.topP,
        tokenBuffer: 256,
      );
      await _chat!.initSession();
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

  /// 非流式生成
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
      await _chat!.addQuery(gemma_msg.Message.text(prompt));
      final response = await _chat!.generateChatResponse();
      return response.text;
    } catch (e) {
      return '⚠️ 生成出错: $e';
    }
  }

  /// 流式生成
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
      await _chat!.addQuery(gemma_msg.Message.text(prompt));
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (_stopRequested) break;
        yield response.text;
      }
    } catch (e) {
      yield '\n\n⚠️ 流式生成出错: $e';
    }
  }

  /// 停止生成
  @override
  void stop() {
    _stopRequested = true;
    _chat?.stopGeneration();
  }
}

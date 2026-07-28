import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../models/model_config.dart';

// =============================================================================
// 抽象 LLM 服务接口
// =============================================================================

/// LLM 推理服务的抽象接口。
/// 支持 load / unload / generate / streamGenerate / stop。
abstract class LlmService {
  /// 是否已加载模型
  bool get isModelLoaded;

  /// 当前加载的模型配置
  ModelConfig? get currentConfig;

  /// 加载模型到内存
  Future<void> loadModel(ModelConfig config);

  /// 卸载模型，释放资源
  Future<void> unloadModel();

  /// 一次性生成完整回复
  Future<String> generate(
    String prompt, {
    List<Message>? history,
    int maxTokens,
    double? temperature,
    double? topP,
  });

  /// 流式逐 token 生成，返回 Stream<String>（每个 token 为一个事件）
  Stream<String> streamGenerate(
    String prompt, {
    List<Message>? history,
    int maxTokens,
    double? temperature,
    double? topP,
  });

  /// 带工具调用的流式生成。
  /// 返回 Stream<String>，其中特殊 token 序列包含 tool_calls 的 JSON。
  /// 格式: 正常文本 token -> {tool_call: {...}} -> 正常文本 ...
  Stream<String> generateWithTools(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
    int maxTokens,
    double? temperature,
    double? topP,
  });

  /// 停止当前推理
  void stop();
}

// =============================================================================
// llama.cpp 实现（mock 模式，当前不实际调用 libllama.so）
// =============================================================================

/// llama.cpp 后端实现（当前 mock 模式）。
///
/// 当前阶段所有 generate 方法返回模拟数据（mock），方便 UI 调试。
/// 后续需接入真实 llama.cpp FFI 调用时，参考 _nativeGenerate 注释。
class LlamaCppService implements LlmService {
  // ---------------------------------------------------------------------------
  // 内部状态
  // ---------------------------------------------------------------------------

  @override
  bool isModelLoaded = false;

  @override
  ModelConfig? currentConfig;

  /// 停止标志，用于中断推理循环
  bool _stopRequested = false;

  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // 构造
  // ---------------------------------------------------------------------------

  LlamaCppService();

  // ---------------------------------------------------------------------------
  // 模型加载 / 卸载（mock：仅设置状态）
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadModel(ModelConfig config) async {
    if (isModelLoaded) {
      await unloadModel();
    }
    // mock 模式：只设置状态，不实际加载模型文件
    isModelLoaded = true;
    currentConfig = config;
    _stopRequested = false;
  }

  @override
  Future<void> unloadModel() async {
    _stopRequested = true;
    isModelLoaded = false;
    currentConfig = null;
  }

  // ---------------------------------------------------------------------------
  // 生成（当前阶段使用 mock 数据）
  // ---------------------------------------------------------------------------

  @override
  Future<String> generate(
    String prompt, {
    List<Message>? history,
    int maxTokens = 1024,
    double? temperature,
    double? topP,
  }) async {
    return _mockGenerate(prompt, history: history);
  }

  @override
  Stream<String> streamGenerate(
    String prompt, {
    List<Message>? history,
    int maxTokens = 1024,
    double? temperature,
    double? topP,
  }) {
    return _mockStreamGenerate(prompt, history: history);
  }

  @override
  Stream<String> generateWithTools(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
    int maxTokens = 1024,
    double? temperature,
    double? topP,
  }) {
    return _mockStreamGenerateWithTools(prompt, history: history, tools: tools);
  }

  @override
  void stop() {
    _stopRequested = true;
  }

  // ---------------------------------------------------------------------------
  // Mock 数据生成（UI 调试用，后续替换为真实 llama.cpp 推理）
  // ---------------------------------------------------------------------------

  /// mock 一次性生成回复
  Future<String> _mockGenerate(
    String prompt, {
    List<Message>? history,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _buildMockResponse(prompt);
  }

  /// mock 流式逐 token 输出
  Stream<String> _mockStreamGenerate(
    String prompt, {
    List<Message>? history,
  }) async* {
    await Future.delayed(const Duration(milliseconds: 500));
    final response = _buildMockResponse(prompt);
    for (int i = 0; i < response.length; i++) {
      if (_stopRequested) break;
      await Future.delayed(Duration(milliseconds: 30 + Random().nextInt(30)));
      yield response[i];
    }
  }

  /// mock 带工具调用的流式生成
  Stream<String> _mockStreamGenerateWithTools(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
  }) async* {
    await Future.delayed(const Duration(milliseconds: 500));

    if (prompt.contains('天气') && tools != null && tools.isNotEmpty) {
      const thinking = '让我查询一下天气信息...';
      for (int i = 0; i < thinking.length; i++) {
        if (_stopRequested) break;
        await Future.delayed(const Duration(milliseconds: 25));
        yield thinking[i];
      }

      final toolCallId = 'call_${_uuid.v4().substring(0, 8)}';
      final toolCallJson = jsonEncode({
        'tool_calls': [
          {
            'id': toolCallId,
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': jsonEncode({'city': '北京'}),
            },
          }
        ],
      });
      await Future.delayed(const Duration(milliseconds: 100));
      yield '\n$toolCallJson\n';
    } else {
      final response = _buildMockResponse(prompt);
      for (int i = 0; i < response.length; i++) {
        if (_stopRequested) break;
        await Future.delayed(Duration(milliseconds: 25 + Random().nextInt(25)));
        yield response[i];
      }
    }
  }

  /// 构建 mock 回复文本
  String _buildMockResponse(String prompt) {
    if (prompt.isEmpty) {
      return '您好！我是本地AI助手，基于llama.cpp推理。请问有什么可以帮助您的？';
    }

    if (prompt.contains('天气')) {
      return '根据查询结果，北京今天晴，气温25-32°C，偏南风2-3级，空气质量良。适合户外活动。';
    }

    if (prompt.contains('代码') || prompt.contains('编程')) {
      return '这是一个简单的 Dart 函数示例：\n\n'
          '```dart\n'
          'void greet(String name) {\n'
          '  print("Hello, \$name!");\n'
          '}\n'
          '```\n\n'
          '需要我解释这个函数的作用吗？';
    }

    if (prompt.length < 20) {
      return '这是一个很好的问题！让我从多个角度为您分析...\n\n'
          '首先，我们需要考虑上下文和实际应用场景。'
          '基于当前信息，我建议从以下几个方面着手解决。';
    }

    return '已收到您的消息。作为本地AI助手，我正在使用llama.cpp进行推理。\n\n'
        '当前模型：${currentConfig?.name ?? "未加载"}\n'
        '（注：当前为 mock 推理模式，真实模型推理将在后续版本中启用）';
  }

  // ---------------------------------------------------------------------------
  // 构建输入文本（带聊天模板）
  // ---------------------------------------------------------------------------

  String _buildPromptText(
    String prompt, {
    List<Message>? history,
  }) {
    final buffer = StringBuffer();

    // 系统提示
    buffer.writeln('<|system|>');
    buffer.writeln('你是一个有帮助的AI助手，运行在本地设备上。');
    buffer.writeln('请用中文回复用户的问题。');
    buffer.writeln('</s>');

    // 历史消息
    if (history != null) {
      for (final msg in history) {
        switch (msg.role) {
          case MessageRole.user:
            buffer.writeln('<|user|>');
            buffer.writeln(msg.content);
            buffer.writeln('</s>');
            break;
          case MessageRole.assistant:
            buffer.writeln('<|assistant|>');
            buffer.writeln(msg.content);
            buffer.writeln('</s>');
            break;
          default:
            break;
        }
      }
    }

    // 当前用户输入
    buffer.writeln('<|user|>');
    buffer.writeln(prompt);
    buffer.writeln('</s>');
    buffer.writeln('<|assistant|>');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // 后续启用：真实 llama.cpp 推理（通过 dart:ffi 调用 libllama.so）
  //
  // 接入时需：
  // 1. 导入 dart:ffi 和 package:ffi/ffi.dart
  // 2. 添加 native 类型定义和函数绑定
  // 3. 实现 _tokenize / _detokenize / _nativeGenerate
  // 4. 在 pubspec.yaml 中添加 ffi: ^2.1.0
  // 5. 将 libllama.so 放入 android/app/src/main/jniLibs/
  // 详细实现参考注释掉的 _nativeGenerate / _tokenize / _detokenize 代码
  // ---------------------------------------------------------------------------
}

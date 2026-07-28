import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/model_config.dart';
import 'memory_service.dart';

// =============================================================================
// 抽象 LLM 服务接口
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
// Ollama 后端实现 — 通过 HTTP API 调用本地 Ollama 服务
// =============================================================================

class OllamaService implements LlmService {
  @override
  bool isModelLoaded = false;

  @override
  ModelConfig? currentConfig;

  bool _stopRequested = false;
  http.Client? _activeClient;
  StreamSubscription? _activeSubscription;

  /// Ollama 服务地址（手机本地，Ollama 默认监听 11434）
  final String baseUrl;

  /// 记忆服务（长对话记忆与自我进化）
  final MemoryService? memoryService;

  OllamaService({this.baseUrl = 'http://localhost:11434', this.memoryService});

  // ---------------------------------------------------------------------------
  // 模型加载 / 卸载
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadModel(ModelConfig config) async {
    if (isModelLoaded) await unloadModel();

    // 校验 Ollama 服务是否可达
    try {
      final resp = await http.get(Uri.parse('$baseUrl/api/tags')).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) {
        throw Exception('Ollama 服务不可用 (HTTP ${resp.statusCode})');
      }
    } on SocketException {
      throw Exception('无法连接到 Ollama，请确保已在 Termux 中运行 ollama serve');
    } on TimeoutException {
      throw Exception('连接 Ollama 超时，请确认 Ollama 已启动');
    }

    isModelLoaded = true;
    currentConfig = config;
    _stopRequested = false;
  }

  @override
  Future<void> unloadModel() async {
    _stopRequested = true;
    await _activeSubscription?.cancel();
    _activeClient?.close();
    isModelLoaded = false;
    currentConfig = null;
  }

  // ---------------------------------------------------------------------------
  // 生成
  // ---------------------------------------------------------------------------

  @override
  Future<String> generate(
    String prompt, {
    List<Message>? history,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) async {
    final modelName = _getModelName();
    final messages = await _buildMessages(prompt, history: history);

    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': modelName,
          'messages': messages,
          'stream': false,
          'options': {
            if (temperature != null) 'temperature': temperature,
            if (topP != null) 'top_p': topP,
            'num_predict': maxTokens,
          },
        }),
      ).timeout(const Duration(seconds: 120));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final msg = data['message'] as Map<String, dynamic>?;
        return (msg?['content'] as String?) ?? '';
      } else {
        return '⚠️ Ollama 返回错误: ${resp.statusCode}\n${resp.body}';
      }
    } catch (e) {
      return '⚠️ 调用 Ollama 失败: $e\n\n'
          '请确保已在 Termux 中运行:\n'
          '  ollama serve\n'
          '并已拉取模型: ollama pull qwen2.5:7b';
    }
  }

  @override
  Stream<String> streamGenerate(
    String prompt, {
    List<Message>? history,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) {
    return _streamChat(prompt, history: history, maxTokens: maxTokens, temperature: temperature, topP: topP);
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
    // 目前 Ollama 的 tool calling 支持有限，先走普通流式
    return _streamChat(prompt, history: history, maxTokens: maxTokens, temperature: temperature, topP: topP);
  }

  @override
  void stop() {
    _stopRequested = true;
    _activeSubscription?.cancel();
    _activeClient?.close();
  }

  // ---------------------------------------------------------------------------
  // 核心：流式对话
  // ---------------------------------------------------------------------------

  Stream<String> _streamChat(
    String prompt, {
    List<Message>? history,
    int maxTokens = 4096,
    double? temperature,
    double? topP,
  }) async* {
    final modelName = _getModelName();
    final messages = await _buildMessages(prompt, history: history);

    _stopRequested = false;
    http.Client client = http.Client();
    _activeClient = client;

    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'model': modelName,
        'messages': messages,
        'stream': true,
        'options': {
          if (temperature != null) 'temperature': temperature,
          if (topP != null) 'top_p': topP,
          'num_predict': maxTokens,
        },
      });

      final streamedResp = await client.send(request).timeout(const Duration(seconds: 180));

      await for (final chunk in streamedResp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (_stopRequested) break;
        if (chunk.trim().isEmpty) continue;

        try {
          final data = jsonDecode(chunk) as Map<String, dynamic>;
          if (data['done'] == true) break;
          final msg = data['message'] as Map<String, dynamic>?;
          final content = msg?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {
          // 跳过解析错误的行
          continue;
        }
      }
    } on SocketException {
      yield '\n\n⚠️ 无法连接到 Ollama。请确保:\n'
          '1. Termux 中已运行: ollama serve\n'
          '2. Ollama 正在监听端口 11434\n'
          '3. 手机和 App 在同一设备上';
    } on TimeoutException {
      yield '\n\n⚠️ 请求超时，Ollama 推理时间过长。';
    } catch (e) {
      yield '\n\n⚠️ 发生错误: $e';
    } finally {
      client.close();
      if (_activeClient == client) {
        _activeClient = null;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 构建 Ollama API 的 messages 格式
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _buildMessages(String prompt, {List<Message>? history}) async {
    final messages = <Map<String, dynamic>>[];

    // 拼接记忆上下文
    String memoryContext = '';
    try {
      if (memoryService != null) {
        memoryContext = await memoryService!.buildMemoryContext(prompt);
      }
    } catch (_) {
      // 记忆服务异常时静默跳过
    }

    // 系统提示
    String systemPrompt = '你是一个有帮助的AI助手，运行在本地设备上，通过 Ollama 进行推理。'
        '你可以使用工具来完成搜索、计算、文件读写等任务。请用中文回复。';

    // 注入记忆上下文（长对话记忆 + 自我进化）
    if (memoryContext.isNotEmpty) {
      systemPrompt += '\n\n以下是我对你的了解（每次对话会自动学习和更新）：$memoryContext';
    }

    messages.add({
      'role': 'system',
      'content': systemPrompt,
    });

    // 历史消息
    if (history != null) {
      for (final msg in history) {
        switch (msg.role) {
          case MessageRole.user:
            messages.add({'role': 'user', 'content': msg.content});
            break;
          case MessageRole.assistant:
            messages.add({'role': 'assistant', 'content': msg.content});
            break;
          default:
            break;
        }
      }
    }

    // 当前用户输入
    messages.add({'role': 'user', 'content': prompt});

    return messages;
  }

  // ---------------------------------------------------------------------------
  // 工具方法
  // ---------------------------------------------------------------------------

  /// 获取当前 Ollama 模型名称
  String _getModelName() {
    if (currentConfig != null && currentConfig!.filePath.isNotEmpty) {
      // 从文件路径推断模型名
      final name = currentConfig!.filePath.split('/').last.replaceAll('.gguf', '');
      if (name.isNotEmpty) return name;
    }
    return 'qwen2.5:7b';
  }
}

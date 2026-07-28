import 'dart:async';
import 'dart:convert';

import '../models/message.dart';
import 'llm_service.dart';

// =============================================================================
// Agent 事件类型
// =============================================================================

/// Agent 执行过程中的事件类型
enum AgentEventType {
  /// 模型正在思考 / 处理中
  thinking,

  /// 文本 token 输出
  text,

  /// 正在调用工具
  toolCall,

  /// 工具执行结果返回
  toolResult,

  /// 本轮执行完成
  done,

  /// 执行出错
  error,
}

// =============================================================================
// Agent 事件
// =============================================================================

/// Agent 执行事件，包含类型和数据
class AgentEvent {
  /// 事件类型
  final AgentEventType type;

  /// 事件携带的数据
  /// - thinking: 思考状态文本
  /// - text: token 文本
  /// - toolCall: Map<String, dynamic> {name, arguments, callId}
  /// - toolResult: Map<String, dynamic> {name, result, callId}
  /// - done: 最终的 Message 对象
  /// - error: 错误信息 String
  final dynamic data;

  const AgentEvent({required this.type, this.data});

  @override
  String toString() => 'AgentEvent(type: $type, data: $data)';
}

// =============================================================================
// 工具定义格式（OpenAI-compatible function calling）
// =============================================================================

/// 工具基类——供 Agent 调用。
/// 注意：此接口需要与项目的实际 ToolBase 保持一致。
/// 如果 ToolBase 子 agent 生成了不同接口，以实际接口为准。
abstract class AgentToolBase {
  /// 工具名称（唯一标识）
  String get name;

  /// 工具描述（用于 LLM 理解）
  String get description;

  /// JSON Schema 格式的参数定义
  Map<String, dynamic> get parameters;

  /// 执行工具，返回结果（字符串或 JSON 可序列化对象）
  Future<dynamic> execute(Map<String, dynamic> arguments);

  /// 转换为 OpenAI function calling 格式
  Map<String, dynamic> toOpenAiFunction() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

// =============================================================================
// Agent 引擎
// =============================================================================

/// Agent 调度引擎——对标 OpenClaw 的 Agent 核心。
///
/// 负责：
/// 1. 组装 System Prompt（包含工具定义）
/// 2. 调用 LLM 流式生成
/// 3. 解析响应中的 tool_calls
/// 4. 执行工具并将结果注入对话
/// 5. 循环直到模型直接回复（最多 5 轮工具调用）
class AgentEngine {
  /// LLM 服务实例（可动态替换，null 表示还未绑定）
  LlmService? llmService;

  /// 最大工具调用回合数（防止死循环）
  final int maxToolCallRounds;

  /// 当前是否正在执行
  bool _isRunning = false;

  /// 停止标志
  bool _stopRequested = false;

  AgentEngine({
    this.llmService,
    this.maxToolCallRounds = 5,
  });

  // ---------------------------------------------------------------------------
  // 主执行入口
  // ---------------------------------------------------------------------------

  /// 执行用户消息，生成 AI 回复。
  ///
  /// [userMessage] 用户当前输入
  /// [history] 历史对话消息列表
  /// [tools] 可用工具列表
  ///
  /// 返回流式 AgentEvent，依次输出 thinking → text/toolCall → ... → done/error
  Stream<AgentEvent> execute(
    String userMessage,
    List<Message> history,
    List<AgentToolBase> tools,
  ) async* {
    _isRunning = true;
    _stopRequested = false;

    int toolCallRound = 0;
    List<Message> workingHistory = List.from(history);

    try {
      // 组装 system prompt（包含工具定义）
      final systemPrompt = _buildSystemPrompt(tools);

      // 当前轮要发送给 LLM 的消息列表
      List<Message> currentMessages = [
        Message(
          id: 'system',
          conversationId: '',
          role: MessageRole.system,
          content: systemPrompt,
          createdAt: DateTime.now(),
        ),
        ...workingHistory,
      ];

      while (toolCallRound < maxToolCallRounds && !_stopRequested) {
        // 发送 thinking 事件
        yield const AgentEvent(type: AgentEventType.thinking, data: '正在思考...');

        // 构建 prompt 文本（将消息列表转为模板格式）
        final promptText = _messagesToPrompt(currentMessages, userMessage);

        // 调用 LLM 流式生成（带工具）
        final toolsList = tools.map((t) => t.toOpenAiFunction()).toList();
        final responseBuffer = StringBuffer();
        bool hasToolCalls = false;

        final service = llmService;
        if (service == null) {
          yield AgentEvent(
            type: AgentEventType.error,
            data: 'LLM 服务未初始化',
          );
          break;
        }

        await for (final token in service.generateWithTools(
          promptText,
          history: currentMessages,
          tools: toolsList,
        )) {
          if (_stopRequested) break;

          responseBuffer.write(token);

          // 检查是否包含 tool_call JSON
          final accumulated = responseBuffer.toString();
          final toolCallMatch = _extractToolCalls(accumulated);

          if (toolCallMatch != null) {
            hasToolCalls = true;

            // 解析出 tool_calls
            final toolCalls = toolCallMatch['tool_calls'] as List<dynamic>;
            for (final tc in toolCalls) {
              final callId = tc['id'] as String;
              final func = tc['function'] as Map<String, dynamic>;
              final funcName = func['name'] as String;
              final funcArgsStr = func['arguments'] as String;
              Map<String, dynamic> funcArgs;
              try {
                funcArgs = jsonDecode(funcArgsStr) as Map<String, dynamic>;
              } catch (_) {
                funcArgs = {};
              }

              // 发送 toolCall 事件
              yield AgentEvent(
                type: AgentEventType.toolCall,
                data: {
                  'callId': callId,
                  'name': funcName,
                  'arguments': funcArgs,
                },
              );

              // 查找并执行工具
              final tool =
                  tools.where((t) => t.name == funcName).firstOrNull;
              dynamic toolResult;
              String? errorMessage;

              if (tool != null) {
                try {
                  toolResult = await tool.execute(funcArgs);
                  yield AgentEvent(
                    type: AgentEventType.toolResult,
                    data: {
                      'callId': callId,
                      'name': funcName,
                      'result': toolResult is String
                          ? toolResult
                          : jsonEncode(toolResult),
                    },
                  );
                } catch (e) {
                  errorMessage = e.toString();
                  yield AgentEvent(
                    type: AgentEventType.toolResult,
                    data: {
                      'callId': callId,
                      'name': funcName,
                      'result': '工具执行出错: $errorMessage',
                    },
                  );
                }
              } else {
                toolResult = '工具未找到: $funcName';
                yield AgentEvent(
                  type: AgentEventType.toolResult,
                  data: {
                    'callId': callId,
                    'name': funcName,
                    'result': toolResult,
                  },
                );
              }
            }

            // 将工具调用和结果注入到消息历史
            currentMessages = await _injectToolMessages(
              currentMessages,
              toolCalls,
              tools,
            );
          }
        }

        if (_stopRequested) break;

        // 如果没有 tool_calls，模型直接给出了回复
        if (!hasToolCalls) {
          final assistantMessage = Message(
            id: 'assistant_${DateTime.now().millisecondsSinceEpoch}',
            conversationId: '',
            role: MessageRole.assistant,
            content: responseBuffer.toString(),
            status: MessageStatus.completed,
            createdAt: DateTime.now(),
          );

          yield AgentEvent(
            type: AgentEventType.done,
            data: assistantMessage,
          );
          break;
        }

        // 有 tool_calls：清空 buffer，继续下一轮
        responseBuffer.clear();
        toolCallRound++;
      }

      // 达到最大工具调用轮数
      if (toolCallRound >= maxToolCallRounds && !_stopRequested) {
        yield AgentEvent(
          type: AgentEventType.error,
          data: '已达到最大工具调用轮数 ($maxToolCallRounds)',
        );
      }
    } catch (e, stack) {
      yield AgentEvent(
        type: AgentEventType.error,
        data: 'Agent 执行出错: $e',
      );
    } finally {
      _isRunning = false;
    }
  }

  /// 停止当前执行
  void stop() {
    _stopRequested = true;
    llmService?.stop();
  }

  // ---------------------------------------------------------------------------
  // System Prompt 构建
  // ---------------------------------------------------------------------------

  /// 构建包含工具定义的 System Prompt
  String _buildSystemPrompt(List<AgentToolBase> tools) {
    final buffer = StringBuffer();

    buffer.writeln('你是一个运行在本地设备上的智能AI助手。');
    buffer.writeln('你可以通过调用工具来获取实时信息或执行操作。');
    buffer.writeln();

    if (tools.isNotEmpty) {
      buffer.writeln('## 可用工具');
      buffer.writeln();
      buffer.writeln('你可以调用以下工具来完成用户的任务。调用工具时，请严格按照指定的 JSON Schema 提供参数。');
      buffer.writeln();

      for (final tool in tools) {
        buffer.writeln('### ${tool.name}');
        buffer.writeln(tool.description);
        buffer.writeln('参数: ${jsonEncode(tool.parameters)}');
        buffer.writeln();
      }

      buffer.writeln('## 工具调用格式');
      buffer.writeln();
      buffer.writeln('当你需要调用工具时，请使用以下 JSON 格式：');
      buffer.writeln();
      buffer.writeln('```json');
      buffer.writeln('{');
      buffer.writeln('  "tool_calls": [{');
      buffer.writeln('    "id": "唯一的调用ID",');
      buffer.writeln('    "type": "function",');
      buffer.writeln('    "function": {');
      buffer.writeln('      "name": "工具名称",');
      buffer.writeln('      "arguments": "{\"参数名\": \"参数值\"}"');
      buffer.writeln('    }');
      buffer.writeln('  }]');
      buffer.writeln('}');
      buffer.writeln('```');
      buffer.writeln();
    }

    buffer.writeln('## 回复要求');
    buffer.writeln('- 请用中文回复');
    buffer.writeln('- 如果用户问题可以通过现有信息回答，直接回复，不要调用工具');
    buffer.writeln('- 只在确实需要外部信息或执行操作时才调用工具');
    buffer.writeln('- 工具调用结果会自动注入对话，请基于结果继续回复');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // 消息列表 → Prompt 文本
  // ---------------------------------------------------------------------------

  /// 将消息列表转换为 LLM prompt 文本（ChatML 格式）
  String _messagesToPrompt(List<Message> messages, String currentUserMessage) {
    final buffer = StringBuffer();

    for (final msg in messages) {
      switch (msg.role) {
        case MessageRole.system:
          buffer.writeln('<|system|>');
          buffer.writeln(msg.content);
          buffer.writeln('</s>');
          break;
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
        case MessageRole.tool:
          // 工具消息：把工具返回结果注入
          buffer.writeln('<|tool|>');
          buffer.writeln(msg.content);
          buffer.writeln('</s>');
          break;
      }
    }

    // 当前用户输入
    buffer.writeln('<|user|>');
    buffer.writeln(currentUserMessage);
    buffer.writeln('</s>');
    buffer.writeln('<|assistant|>');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Tool Call 解析
  // ---------------------------------------------------------------------------

  /// 从 LLM 输出中提取 tool_calls JSON
  /// 返回 null 表示未检测到 tool_call
  Map<String, dynamic>? _extractToolCalls(String text) {
    // 尝试匹配 JSON 块中的 tool_calls
    final toolCallPattern = RegExp(
      r'\{[^{}]*"tool_calls"\s*:\s*\[',
      multiLine: true,
    );

    final match = toolCallPattern.firstMatch(text);
    if (match == null) return null;

    // 从匹配位置开始提取完整 JSON 对象
    int start = match.start;
    int braceCount = 0;
    int end = start;
    bool inString = false;
    bool escaped = false;

    for (int i = start; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == '{') {
        braceCount++;
      } else if (ch == '}') {
        braceCount--;
        if (braceCount == 0) {
          end = i + 1;
          break;
        }
      }
    }

    final jsonStr = text.substring(start, end);
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 工具消息注入
  // ---------------------------------------------------------------------------

  /// 将工具调用和结果注入到消息历史中
  Future<List<Message>> _injectToolMessages(
    List<Message> currentMessages,
    List<dynamic> toolCalls,
    List<AgentToolBase> tools,
  ) async {
    final newMessages = List<Message>.from(currentMessages);

    for (final tc in toolCalls) {
      final func = tc['function'] as Map<String, dynamic>;
      final funcName = func['name'] as String;
      final funcArgsStr = func['arguments'] as String;
      final callId = tc['id'] as String;

      // 构造 assistant 消息（含 tool_calls）
      var toolCallInfo = ToolCallInfo(
        id: callId,
        name: funcName,
        arguments: jsonDecode(funcArgsStr) as Map<String, dynamic>,
        status: ToolCallStatus.completed,
      );

      newMessages.add(Message(
        id: 'assistant_tool_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: '',
        role: MessageRole.assistant,
        content: '',
        toolCalls: [toolCallInfo],
        createdAt: DateTime.now(),
      ));

      // 查找并执行工具
      final tool = tools.where((t) => t.name == funcName).firstOrNull;
      String resultStr;
      if (tool != null) {
        try {
          final result = await _executeToolSync(tool, toolCallInfo.arguments);
          resultStr = result is String ? result : jsonEncode(result);
          toolCallInfo = ToolCallInfo(
            id: callId,
            name: funcName,
            arguments: toolCallInfo.arguments,
            result: resultStr,
            status: ToolCallStatus.completed,
          );
        } catch (e) {
          resultStr = '工具执行出错: $e';
          toolCallInfo = ToolCallInfo(
            id: callId,
            name: funcName,
            arguments: toolCallInfo.arguments,
            result: resultStr,
            status: ToolCallStatus.error,
          );
        }
      } else {
        resultStr = '工具未找到: $funcName';
      }

      // 构造 tool 角色消息
      newMessages.add(Message(
        id: 'tool_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: '',
        role: MessageRole.tool,
        content: resultStr,
        createdAt: DateTime.now(),
      ));
    }

    return newMessages;
  }

  /// 同步执行工具（包装异步调用）
  Future<String> _executeToolSync(
    AgentToolBase tool,
    Map<String, dynamic> arguments,
  ) async {
    final result = await tool.execute(arguments);
    return result is String ? result : jsonEncode(result);
  }

  /// 是否正在运行
  bool get isRunning => _isRunning;
}

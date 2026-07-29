import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/message.dart';
import '../../services/agent_engine.dart';
import '../../services/conversation_service.dart';
import '../../services/model_manager.dart';
import '../../tools/tool_base.dart';
import '../../tools/tool_registry.dart';
import '../../utils/constants.dart';
import '../settings/settings_page.dart';
import 'chat_input.dart';
import 'message_bubble.dart';

/// 主聊天页面
class ChatPage extends StatefulWidget {
  final String? conversationId;
  final ModelManager modelManager;
  final AgentEngine agentEngine;
  final ConversationService conversationService;
  final ToolRegistry toolRegistry;

  const ChatPage({
    super.key,
    this.conversationId,
    required this.modelManager,
    required this.agentEngine,
    required this.conversationService,
    required this.toolRegistry,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isGenerating = false;
  String _conversationId = '';

  /// 当前流式输出的内容缓存
  String _streamingContent = '';

  /// Agent 流订阅
  StreamSubscription<AgentEvent>? _agentSubscription;

  @override
  void initState() {
    super.initState();
    _conversationId =
        widget.conversationId ?? DateTime.now().millisecondsSinceEpoch.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createNewConversation();
    });
  }

  @override
  void dispose() {
    _agentSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 获取当前模型名称
  String get _modelName {
    final config = widget.modelManager.currentConfig;
    return config?.name ?? '未加载模型';
  }

  /// 获取模型加载状态
  bool get _modelLoaded => widget.modelManager.isModelLoaded;

  /// 创建新对话
  void _createNewConversation() {
    _agentSubscription?.cancel();
    setState(() {
      _messages = [_createSystemMessage()];
      _conversationId = DateTime.now().millisecondsSinceEpoch.toString();
      _streamingContent = '';
      _isGenerating = false;
    });
  }

  /// 创建系统提示消息
  Message _createSystemMessage() {
    return Message(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _conversationId,
      role: MessageRole.system,
      content: '你是本地AI助手，运行在设备上，基于本地大模型提供智能对话服务。你可以使用工具来完成搜索、计算、文件读写等任务。请用中文回复。',
      createdAt: DateTime.now(),
    );
  }

  /// 发送消息
  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _isGenerating) return;

    final userMessage = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _conversationId,
      role: MessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isGenerating = true;
      _streamingContent = '';
    });

    _scrollToBottom();

    // 检查模型是否已加载
    if (!_modelLoaded) {
      _showErrorAndStop('模型未加载，请先在设置中选择并加载模型');
      return;
    }

    // 创建AI占位消息（空内容，streaming状态）
    final aiMessageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_ai';
    final aiMessage = Message(
      id: aiMessageId,
      conversationId: _conversationId,
      role: MessageRole.assistant,
      content: '',
      status: MessageStatus.streaming,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(aiMessage);
    });

    // 构建历史消息（排除刚添加的user消息，execute会自动加上）
    final historyMessages = _messages
        .where((m) => m.role != MessageRole.system && m.id != userMessage.id)
        .toList();
    final tools = widget.toolRegistry.getAllTools();

    try {
      // 订阅 Agent 事件流
      _agentSubscription = widget.agentEngine
          .execute(text, historyMessages, tools)
          .listen((event) {
        if (!mounted) return;

        switch (event.type) {
          case AgentEventType.thinking:
            // 思考状态，不更新内容
            break;

          case AgentEventType.text:
            // 追加文本 token，实现打字机效果
            _streamingContent += (event.data as String);
            _updateAiMessage(aiMessageId, _streamingContent,
                status: MessageStatus.streaming);
            break;

          case AgentEventType.toolCall:
            // 工具调用开始
            final data = event.data as Map<String, dynamic>;
            final toolName = data['name'] as String;
            final toolArgs = data['arguments'] as Map<String, dynamic>;
            final callId = data['callId'] as String;

            // 追加工具调用信息到内容
            _streamingContent += '\n\n🔧 **调用工具: $toolName**\n';
            _updateAiMessage(aiMessageId, _streamingContent,
                status: MessageStatus.streaming);
            break;

          case AgentEventType.toolResult:
            // 工具执行结果
            final data = event.data as Map<String, dynamic>;
            final toolName = data['name'] as String;

            _streamingContent += '\n✅ **$toolName 执行完成**\n\n';
            _updateAiMessage(aiMessageId, _streamingContent,
                status: MessageStatus.streaming);
            break;

          case AgentEventType.done:
            // 最终回复
            final finalMessage = event.data as Message;
            _updateAiMessage(aiMessageId, finalMessage.content,
                status: MessageStatus.completed);
            _onGenerationComplete(aiMessageId);
            break;

          case AgentEventType.error:
            // 出错
            final errorText = event.data as String;
            _updateAiMessage(aiMessageId, _streamingContent + '\n\n⚠️ $errorText',
                status: MessageStatus.error,
                errorMessage: errorText);
            _onGenerationComplete(aiMessageId);
            break;
        }
      }, onDone: () {
        // 流自然结束，没有收到 done/error 事件
        if (_streamingContent.isNotEmpty) {
          _updateAiMessage(aiMessageId, _streamingContent,
              status: MessageStatus.completed);
        }
        _onGenerationComplete(aiMessageId);
      }, onError: (error) {
        if (!mounted) return;
        _updateAiMessage(aiMessageId,
            _streamingContent + '\n\n⚠️ $error',
            status: MessageStatus.error,
            errorMessage: error.toString());
        _onGenerationComplete(aiMessageId);
      });
    } catch (e) {
      _updateAiMessage(aiMessageId,
          _streamingContent + '\n\n⚠️ 执行出错: $e',
          status: MessageStatus.error,
          errorMessage: e.toString());
      _onGenerationComplete(aiMessageId);
    }
  }

  /// 更新 AI 消息
  void _updateAiMessage(
    String messageId,
    String content, {
    required MessageStatus status,
    String? errorMessage,
  }) {
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          content: content,
          status: status,
          errorMessage: errorMessage,
        );
      }
    });
    _scrollToBottom();
  }

  /// 生成完成后的清理
  void _onGenerationComplete(String aiMessageId) {
    if (!mounted) return;
    setState(() {
      _isGenerating = false;
      _streamingContent = '';
    });
    _agentSubscription?.cancel();
    _agentSubscription = null;
    _scrollToBottom();
  }

  /// 显示错误并停止
  void _showErrorAndStop(String errorMessage) {
    setState(() {
      _isGenerating = false;
    });
    // 添加错误提示消息
    if (_messages.isNotEmpty) {
      final lastMsg = _messages.last;
      if (lastMsg.role == MessageRole.assistant &&
          lastMsg.status == MessageStatus.streaming) {
        _messages[_messages.length - 1] = lastMsg.copyWith(
          content: errorMessage,
          status: MessageStatus.error,
          errorMessage: errorMessage,
        );
      } else {
        _messages.add(Message(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          conversationId: _conversationId,
          role: MessageRole.assistant,
          content: errorMessage,
          status: MessageStatus.error,
          errorMessage: errorMessage,
          createdAt: DateTime.now(),
        ));
      }
    }
    _scrollToBottom();
  }

  /// 停止生成
  void _stopGenerating() {
    _agentSubscription?.cancel();
    _agentSubscription = null;
    widget.agentEngine.stop();

    setState(() {
      _isGenerating = false;
      // 将正在流式输出的消息标记为完成
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].status == MessageStatus.streaming) {
          _messages[i] = _messages[i].copyWith(
            content: _messages[i].content.isEmpty
                ? '（已停止生成）'
                : _messages[i].content,
            status: MessageStatus.completed,
          );
        }
      }
      _streamingContent = '';
    });
  }

  /// 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// 打开设置页面
  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          modelManager: widget.modelManager,
        ),
      ),
    );
    // 从设置页面返回后刷新状态
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    reverse: false,
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isLastAi =
                          index == _messages.length - 1 &&
                          message.role == MessageRole.assistant &&
                          _isGenerating;

                      return MessageBubble(
                        message: message,
                        isLastAiMessage: isLastAi,
                        isStreaming: isLastAi && _isGenerating,
                      );
                    },
                  ),
          ),
          // 输入框
          ChatInput(
            controller: _textController,
            focusNode: _focusNode,
            onSend: _sendMessage,
            isGenerating: _isGenerating,
          ),
        ],
      ),
    );
  }

  /// 顶部栏
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppConstants.surfaceColor,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本地智能助手',
            style: TextStyle(
              color: AppConstants.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: _isGenerating
                      ? AppConstants.accentColor
                      : _modelLoaded
                          ? AppConstants.successColor
                          : AppConstants.errorColor,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                _isGenerating
                    ? '生成中...'
                    : _modelLoaded
                        ? _modelName
                        : '⚠️ 未加载模型',
                style: TextStyle(
                  color: AppConstants.textSecondary.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // 停止生成按钮
        if (_isGenerating)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppConstants.errorColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.stop,
                color: AppConstants.errorColor,
                size: 18,
              ),
            ),
            onPressed: _stopGenerating,
            tooltip: '停止生成',
          ),
        // 新建对话
        IconButton(
          icon: const Icon(
            Icons.add_comment,
            color: AppConstants.textSecondary,
            size: 20,
          ),
          onPressed: _createNewConversation,
          tooltip: '新建对话',
        ),
        // 设置
        IconButton(
          icon: const Icon(
            Icons.settings,
            color: AppConstants.textSecondary,
            size: 20,
          ),
          onPressed: _openSettings,
          tooltip: '设置',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: Colors.white.withOpacity(0.05),
          height: 1,
        ),
      ),
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology,
                color: AppConstants.primaryColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '本地AI助手',
              style: TextStyle(
                color: AppConstants.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '基于本地大模型推理，隐私安全\n支持工具调用、联网搜索',
              style: TextStyle(
                color: AppConstants.textSecondary.withOpacity(0.7),
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // 模型加载状态提示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _modelLoaded
                    ? AppConstants.successColor.withOpacity(0.1)
                    : AppConstants.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _modelLoaded ? Icons.check_circle : Icons.warning,
                    size: 14,
                    color: _modelLoaded
                        ? AppConstants.successColor
                        : AppConstants.errorColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _modelLoaded ? '模型已加载' : '模型未加载',
                    style: TextStyle(
                      fontSize: 13,
                      color: _modelLoaded
                          ? AppConstants.successColor
                          : AppConstants.errorColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSuggestionChips(),
          ],
        ),
      ),
    );
  }

  /// 建议问题 chips
  Widget _buildSuggestionChips() {
    final suggestions = [
      '帮我写一段Python代码',
      '今天天气怎么样？',
      '解释什么是量子计算',
      '帮我翻译一段英文',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: suggestions.map((text) {
        return ActionChip(
          label: Text(
            text,
            style: TextStyle(
              color: AppConstants.textPrimary.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
          backgroundColor: AppConstants.surfaceColor,
          side: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onPressed: _modelLoaded ? () => _sendMessage(text) : null,
        );
      }).toList(),
    );
  }
}

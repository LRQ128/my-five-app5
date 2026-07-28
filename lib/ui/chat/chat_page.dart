import 'package:flutter/material.dart';
import '../../models/message.dart';
import '../../utils/constants.dart';
import 'chat_input.dart';
import 'message_bubble.dart';
import 'thinking_indicator.dart';

/// 主聊天页面
class ChatPage extends StatefulWidget {
  final String? conversationId;

  const ChatPage({super.key, this.conversationId});

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
  String _modelName = 'Qwen2.5-7B-Q4_K_M';

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
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 创建新对话
  void _createNewConversation() {
    setState(() {
      _messages = [_createSystemMessage()];
      _conversationId = DateTime.now().millisecondsSinceEpoch.toString();
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
    });

    _scrollToBottom();

    // 创建AI占位消息
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

    // 模拟流式输出
    await _simulateStreamingResponse(aiMessageId, text);

    setState(() {
      _isGenerating = false;
    });

    _scrollToBottom();
  }

  /// 模拟流式响应（实际对接AgentEngine）
  Future<void> _simulateStreamingResponse(String aiMessageId, String userText) async {
    final responseText = _generateMockResponse(userText);

    for (int i = 0; i < responseText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));

      if (!mounted) return;

      setState(() {
        final index = _messages.indexWhere((m) => m.id == aiMessageId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            content: responseText.substring(0, i + 1),
          );
        }
      });
    }

    // 完成流式输出
    setState(() {
      final index = _messages.indexWhere((m) => m.id == aiMessageId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          status: MessageStatus.completed,
        );
      }
    });
  }

  /// 生成模拟回复
  String _generateMockResponse(String userInput) {
    if (userInput.contains('你好') || userInput.contains('hi') || userInput.contains('hello')) {
      return '你好！我是本地AI助手，运行在你的设备上。我能帮你回答问题、搜索信息、执行计算等。有什么我可以帮助你的吗？';
    } else if (userInput.contains('天气')) {
      return '我目前无法直接获取实时天气数据，因为需要通过工具调用联网搜索。\n\n不过我可以尝试使用搜索工具来获取天气信息。你想让我搜索哪个城市的天气？';
    } else if (userInput.contains('代码') || userInput.contains('code')) {
      return '我可以帮你编写和解释代码！请告诉我你想实现什么功能？支持的语言包括 Dart, Python, JavaScript, C++ 等。';
    } else if (userInput.contains('工具')) {
      return '我支持以下工具调用：\n\n- **web_search**: 联网搜索获取实时信息\n- **calculator**: 数学计算\n- **code_execution**: 代码执行\n- **file_read/file_write**: 文件读写\n\n你可以在设置中管理工具的启用/禁用。';
    } else {
      return '收到你的消息："$userInput"\n\n这是一个模拟回复。实际环境中，这里会接入 AgentEngine 进行本地大模型推理，并且支持工具调用和联网搜索等功能。';
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// 停止生成
  void _stopGenerating() {
    setState(() {
      _isGenerating = false;
      // 将正在流式输出的消息标记为完成
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].status == MessageStatus.streaming) {
          _messages[i] = _messages[i].copyWith(
            status: MessageStatus.completed,
          );
        }
      }
    });
  }

  /// 打开设置页面
  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const _SettingsPagePlaceholder(),
      ),
    );
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
                      : AppConstants.successColor,
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                _isGenerating ? '生成中...' : '$_modelName',
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
          const SizedBox(height: 32),
          _buildSuggestionChips(),
        ],
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
          onPressed: () => _sendMessage(text),
        );
      }).toList(),
    );
  }
}

/// 设置页面占位器（实际导航到 SettingsPage）
class _SettingsPagePlaceholder extends StatelessWidget {
  const _SettingsPagePlaceholder();

  @override
  Widget build(BuildContext context) {
    // 实际应导入 SettingsPage
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.surfaceColor,
        title: const Text(
          '设置',
          style: TextStyle(color: AppConstants.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppConstants.textSecondary),
      ),
      body: const Center(
        child: Text(
          '设置页面（需导入settings/settings_page.dart）',
          style: TextStyle(color: AppConstants.textSecondary),
        ),
      ),
    );
  }
}

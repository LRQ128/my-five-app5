import 'dart:convert' show JsonEncoder;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../models/message.dart';
import '../../utils/constants.dart';
import '../widgets/common_widgets.dart';

/// 消息气泡组件
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isLastAiMessage;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.isLastAiMessage = false,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (message.role) {
      case MessageRole.user:
        return _buildUserBubble(context);
      case MessageRole.assistant:
        return _buildAiBubble(context);
      case MessageRole.system:
        return _buildSystemMessage(context);
      case MessageRole.tool:
        return _buildToolResultBubble(context);
    }
  }

  /// 用户消息气泡——右对齐
  Widget _buildUserBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width *
                    AppConstants.maxBubbleWidth,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppConstants.userBubbleColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.borderRadius),
                  topRight: Radius.circular(AppConstants.borderRadius),
                  bottomLeft: Radius.circular(AppConstants.borderRadius),
                  bottomRight: const Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SelectableText(
                    message.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  if (message.status == MessageStatus.error)
                    _buildErrorIndicator(context),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildAvatar(isUser: true),
        ],
      ),
    );
  }

  /// AI消息气泡——左对齐，带 Markdown 渲染
  Widget _buildAiBubble(BuildContext context) {
    // 流式输出中显示打字机效果
    final isThinking = isStreaming &&
        isLastAiMessage &&
        message.status == MessageStatus.streaming;

    if (isThinking && message.content.isEmpty) {
      return _buildThinkingBubble();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(isUser: false),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width *
                    AppConstants.maxBubbleWidth,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppConstants.aiBubbleColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppConstants.borderRadius),
                  topRight: Radius.circular(AppConstants.borderRadius),
                  bottomRight: Radius.circular(AppConstants.borderRadius),
                  bottomLeft: const Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Markdown 渲染
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: AppConstants.textPrimary,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      h1: const TextStyle(
                        color: AppConstants.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: const TextStyle(
                        color: AppConstants.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: const TextStyle(
                        color: AppConstants.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      code: TextStyle(
                        color: AppConstants.accentColor,
                        backgroundColor:
                            AppConstants.backgroundColor.withOpacity(0.5),
                        fontSize: 13,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: AppConstants.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppConstants.primaryColor,
                            width: 3,
                          ),
                        ),
                      ),
                      a: const TextStyle(
                        color: AppConstants.accentColor,
                        decoration: TextDecoration.underline,
                      ),
                      tableBorder: TableBorder.all(
                        color: AppConstants.textSecondary.withOpacity(0.3),
                        width: 1,
                      ),
                      tableHead: const TextStyle(
                        color: AppConstants.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 打字机光标（流式输出时）
                  if (isStreaming && message.content.isNotEmpty)
                    _buildTypingCursor(),

                  // 工具调用卡片
                  if (message.toolCalls != null &&
                      message.toolCalls!.isNotEmpty)
                    ...message.toolCalls!
                        .map((tc) => _buildToolCallCard(context, tc)),

                  // 错误状态
                  if (message.status == MessageStatus.error) ...[
                    const SizedBox(height: 8),
                    _buildErrorBubble(context, message.errorMessage),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 思考中状态气泡
  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(isUser: false),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppConstants.aiBubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.borderRadius),
                topRight: Radius.circular(AppConstants.borderRadius),
                bottomRight: Radius.circular(AppConstants.borderRadius),
                bottomLeft: const Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DotAnimation(color: AppConstants.primaryColor),
                const SizedBox(width: 4),
                _DotAnimation(
                  color: AppConstants.primaryColor,
                  delayMs: 150,
                ),
                const SizedBox(width: 4),
                _DotAnimation(
                  color: AppConstants.primaryColor,
                  delayMs: 300,
                ),
                const SizedBox(width: 10),
                Text(
                  '思考中...',
                  style: TextStyle(
                    color: AppConstants.textSecondary.withOpacity(0.7),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 系统消息
  Widget _buildSystemMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppConstants.textSecondary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: AppConstants.textSecondary.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// 工具结果消息
  Widget _buildToolResultBubble(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppConstants.successColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppConstants.successColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  size: 14, color: AppConstants.successColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  message.content,
                  style: const TextStyle(
                    color: AppConstants.successColor,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 工具调用卡片——带展开/折叠
  Widget _buildToolCallCard(BuildContext context, ToolCallInfo toolCall) {
    return StatefulBuilder(
      builder: (context, setState) {
        final isExpanded = _toolCallExpanded[toolCall.id] ?? false;

        return Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: AppConstants.backgroundColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _getToolStatusColor(toolCall.status).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 工具名头部
              InkWell(
                onTap: () {
                  setState(() {
                    _toolCallExpanded[toolCall.id] = !isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(
                        _getToolIcon(toolCall.name),
                        size: 16,
                        color: _getToolStatusColor(toolCall.status),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          toolCall.name,
                          style: TextStyle(
                            color: _getToolStatusColor(toolCall.status),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _buildToolStatusBadge(toolCall.status),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 展开内容
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(
                        height: 1,
                        color: Color(0xFF3D3D5C),
                      ),
                      const SizedBox(height: 8),
                      // 调用参数
                      if (toolCall.arguments.isNotEmpty) ...[
                        Text(
                          '调用参数',
                          style: TextStyle(
                            color: AppConstants.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            const JsonEncoder.withIndent('  ')
                                .convert(toolCall.arguments),
                            style: const TextStyle(
                              color: AppConstants.accentColor,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                      // 执行结果
                      if (toolCall.result != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '执行结果',
                          style: TextStyle(
                            color: AppConstants.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.backgroundColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            toolCall.result!,
                            maxLines: 10,
                            style: TextStyle(
                              color: AppConstants.textPrimary.withOpacity(0.8),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                crossFadeState:
                    isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 错误消息气泡
  Widget _buildErrorBubble(BuildContext context, String? errorMessage) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppConstants.errorColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: AppConstants.errorColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage ?? '发生未知错误',
              style: const TextStyle(
                color: AppConstants.errorColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 错误指示器（用户消息中）
  Widget _buildErrorIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              size: 14, color: AppConstants.errorColor),
          const SizedBox(width: 4),
          Text(
            '发送失败',
            style: TextStyle(
              color: AppConstants.errorColor.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 打字机光标
  Widget _buildTypingCursor() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value < 0.5 ? 1.0 : 0.0,
          child: child,
        );
      },
      child: Container(
        width: 2,
        height: 18,
        margin: const EdgeInsets.only(left: 2, top: 2),
        decoration: BoxDecoration(
          color: AppConstants.primaryColor,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  /// 头像
  Widget _buildAvatar({required bool isUser}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? AppConstants.primaryColor : AppConstants.accentColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          isUser ? Icons.person : Icons.psychology,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  /// 获取工具状态颜色
  Color _getToolStatusColor(ToolCallStatus status) {
    switch (status) {
      case ToolCallStatus.pending:
        return AppConstants.textSecondary;
      case ToolCallStatus.running:
        return AppConstants.accentColor;
      case ToolCallStatus.completed:
        return AppConstants.successColor;
      case ToolCallStatus.error:
        return AppConstants.errorColor;
    }
  }

  /// 获取工具图标
  IconData _getToolIcon(String toolName) {
    switch (toolName) {
      case 'web_search':
      case 'search':
        return Icons.search;
      case 'calculator':
      case 'calc':
        return Icons.calculate;
      case 'code_execution':
      case 'code':
        return Icons.code;
      case 'file_read':
      case 'read_file':
        return Icons.description;
      case 'file_write':
      case 'write_file':
        return Icons.edit_note;
      case 'image_generation':
      case 'draw':
        return Icons.image;
      default:
        return Icons.build;
    }
  }

  /// 工具状态角标
  Widget _buildToolStatusBadge(ToolCallStatus status) {
    String label;
    Color color;

    switch (status) {
      case ToolCallStatus.pending:
        label = '等待中';
        color = AppConstants.textSecondary;
        break;
      case ToolCallStatus.running:
        label = '执行中';
        color = AppConstants.accentColor;
        break;
      case ToolCallStatus.completed:
        label = '完成';
        color = AppConstants.successColor;
        break;
      case ToolCallStatus.error:
        label = '错误';
        color = AppConstants.errorColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 单个弹跳圆点（简化版，用于思考气泡）
class _DotAnimation extends StatefulWidget {
  final Color color;
  final int delayMs;

  const _DotAnimation({
    required this.color,
    this.delayMs = 0,
  });

  @override
  State<_DotAnimation> createState() => _DotAnimationState();
}

class _DotAnimationState extends State<_DotAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -4 * _animation.value),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

/// 全局工具调用展开状态
final Map<String, bool> _toolCallExpanded = {};

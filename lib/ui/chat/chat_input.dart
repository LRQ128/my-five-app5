import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 聊天输入框组件
class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String text)? onSend;
  final bool isGenerating;
  final int maxLength;

  const ChatInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onSend,
    this.isGenerating = false,
    this.maxLength = 4096,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _hasText = widget.controller.text.trim().isNotEmpty;
    });
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || widget.isGenerating) return;
    widget.onSend?.call(text);
    widget.controller.clear();
    setState(() {
      _hasText = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppConstants.backgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 多行输入框
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppConstants.inputMinHeight,
                    maxHeight: AppConstants.inputMaxHeight,
                  ),
                  decoration: BoxDecoration(
                    color: AppConstants.inputBgColor,
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    enabled: !widget.isGenerating,
                    maxLines: null,
                    minLines: 1,
                    maxLength: widget.maxLength,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      color: AppConstants.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.isGenerating ? '模型生成中...' : '输入消息...',
                      hintStyle: TextStyle(
                        color: AppConstants.textSecondary.withOpacity(0.6),
                        fontSize: 15,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: (_) => _onTextChanged(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 发送按钮
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _hasText && !widget.isGenerating
                      ? AppConstants.primaryColor
                      : AppConstants.inputBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hasText && !widget.isGenerating
                        ? Colors.transparent
                        : Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  onPressed: (_hasText && !widget.isGenerating)
                      ? _handleSend
                      : null,
                  icon: Icon(
                    widget.isGenerating ? Icons.stop : Icons.arrow_upward,
                    color: _hasText && !widget.isGenerating
                        ? Colors.white
                        : AppConstants.textSecondary,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  splashRadius: 20,
                ),
              ),
            ],
          ),
          // 底部状态栏
          if (widget.controller.text.length > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(
                    '${widget.controller.text.length} / ${widget.maxLength}',
                    style: TextStyle(
                      color: widget.controller.text.length > widget.maxLength * 0.9
                          ? AppConstants.errorColor
                          : AppConstants.textSecondary.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  if (widget.isGenerating)
                    Text(
                      '模型正在生成回复...',
                      style: TextStyle(
                        color: AppConstants.accentColor.withOpacity(0.7),
                        fontSize: 11,
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
}

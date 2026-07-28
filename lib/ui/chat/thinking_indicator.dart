import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// 思考指示器——三个弹跳圆点 + 可选文字提示
class ThinkingIndicator extends StatefulWidget {
  final String? text;
  final double dotSize;
  final Color? color;

  const ThinkingIndicator({
    super.key,
    this.text,
    this.dotSize = 8.0,
    this.color,
  });

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  static const int _dotCount = 3;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_dotCount, (index) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      return controller;
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    _startAnimation();
  }

  void _startAnimation() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppConstants.primaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_dotCount, (index) {
            return AnimatedBuilder(
              animation: _animations[index],
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -8 * _animations[index].value),
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    margin: EdgeInsets.symmetric(
                      horizontal: widget.dotSize * 0.5,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            );
          }),
        ),
        if (widget.text != null) ...[
          const SizedBox(width: 10),
          Text(
            widget.text!,
            style: const TextStyle(
              color: AppConstants.textSecondary,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

/// 思考中状态卡片——在AI气泡中使用
class ThinkingCard extends StatelessWidget {
  final String? statusText;

  const ThinkingCard({super.key, this.statusText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppConstants.aiBubbleColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppConstants.borderRadius),
          topRight: Radius.circular(AppConstants.borderRadius),
          bottomRight: Radius.circular(AppConstants.borderRadius),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: ThinkingIndicator(
        text: statusText ?? '思考中...',
        dotSize: 6,
      ),
    );
  }
}

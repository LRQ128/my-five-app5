import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  /// App 名称
  static const String appName = '本地智能助手';

  /// 默认模型配置
  static const String defaultModelPath = 'assets/models/model.gguf';
  static const int defaultContextSize = 4096;
  static const int defaultMaxTokens = 2048;
  static const double defaultTemperature = 0.7;
  static const double defaultTopP = 0.9;
  static const int defaultThreads = 4;

  /// 数据库
  static const String dbName = 'local_ai_assistant.db';
  static const int dbVersion = 1;

  /// UI
  static const double maxBubbleWidth = 0.8;
  static const double borderRadius = 20.0;
  static const double inputMinHeight = 48.0;
  static const double inputMaxHeight = 120.0;
  static const Duration typingAnimationSpeed = Duration(milliseconds: 30);

  /// 工具相关
  static const int maxToolCallRetries = 3;
  static const Duration toolCallTimeout = Duration(seconds: 30);

  /// 颜色主题
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color userBubbleColor = Color(0xFF6C63FF);
  static const Color aiBubbleColor = Color(0xFF2D2D3F);
  static const Color backgroundColor = Color(0xFF1A1A2E);
  static const Color surfaceColor = Color(0xFF16213E);
  static const Color inputBgColor = Color(0xFF2D2D3F);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color accentColor = Color(0xFF00D9FF);
  static const Color errorColor = Color(0xFFFF4757);
  static const Color successColor = Color(0xFF2ED573);
}

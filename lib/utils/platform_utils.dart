import 'dart:io';

/// 平台工具类
class PlatformUtils {
  PlatformUtils._();

  /// 获取可用CPU线程数（用于推理）
  static int getAvailableThreads() {
    try {
      return Platform.numberOfProcessors;
    } catch (_) {
      return 4;
    }
  }

  /// 获取可用内存(MB)
  static Future<int> getAvailableMemoryMB() async {
    // 实际Android端通过Platform Channel获取
    // 这里返回默认值
    return 4096;
  }

  /// 是否为Android
  static bool get isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// 模型文件基础路径
  static String get modelsBasePath {
    // Android端实际路径在应用私有目录
    return 'assets/models/';
  }
}

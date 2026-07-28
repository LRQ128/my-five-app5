/// 工具基类——所有具体 Tool 的抽象父类。
///
/// 每个工具暴露一个 [name]（供 LLM function calling 匹配）、
/// 一段 [description]（填入 OpenAI function definition）、
/// 以及 JSON-Schema 风格的 [parameters] 定义。
///
/// 子类只需重写 [execute] 方法即可接入工具注册中心 [ToolRegistry]。
library tool_base;

/// 工具基类
abstract class ToolBase {
  /// 工具名称，如 "web_search"、"calculator" 等
  final String name;

  /// 工具功能描述，会出现在 OpenAI function definition 中
  final String description;

  /// JSON-Schema 风格的参数定义
  ///
  /// 示例：
  /// ```dart
  /// {
  ///   "type": "object",
  ///   "properties": {
  ///     "query": {"type": "string", "description": "搜索关键词"}
  ///   },
  ///   "required": ["query"]
  /// }
  /// ```
  final Map<String, dynamic> parameters;

  const ToolBase({
    required this.name,
    required this.description,
    required this.parameters,
  });

  /// 执行工具，接收参数 [args]，返回结果字符串。
  ///
  /// 每个子类必须实现自己的业务逻辑。
  Future<String> execute(Map<String, dynamic> args);

  /// 生成 OpenAI-compatible function calling 格式。
  ///
  /// 返回格式：
  /// ```json
  /// {
  ///   "type": "function",
  ///   "function": {
  ///     "name": "web_search",
  ///     "description": "...",
  ///     "parameters": {...}
  ///   }
  /// }
  /// ```
  Map<String, dynamic> toFunctionDefinition() {
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': parameters,
      },
    };
  }

  @override
  String toString() => 'ToolBase($name)';
}

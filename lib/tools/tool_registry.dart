/// 工具注册中心。
///
/// 管理所有 Tool 实例的注册、注销、启用/停用和查询。
/// 默认注册 5 个内置工具：WebSearchTool, CalculatorTool, WeatherTool,
/// NoteTool, CalendarTool。
///
/// 使用示例：
/// ```dart
/// final registry = ToolRegistry();
/// // 获取所有工具的 OpenAI function calling 定义
/// final definitions = registry.getFunctionDefinitions();
/// // 执行某个工具
/// final result = await registry.getTool('calculator')?.execute({'expression': '1+2'});
/// ```
library tool_registry;

import 'tool_base.dart';
import 'web_search_tool.dart';
import 'calculator_tool.dart';
import 'weather_tool.dart';
import 'note_tool.dart';
import 'calendar_tool.dart';

/// 工具注册中心
class ToolRegistry {
  /// 所有已注册的工具（包括已禁用的）
  final Map<String, ToolBase> _tools = {};

  /// 已禁用的工具名称集合
  final Set<String> _disabledTools = {};

  /// 创建默认的工具注册中心，注册所有内置工具
  ToolRegistry() {
    _registerDefaults();
  }

  /// 注册默认内置工具
  void _registerDefaults() {
    register(WebSearchTool());
    register(CalculatorTool());
    register(WeatherTool());
    register(NoteTool());
    register(CalendarTool());
  }

  /// 注册一个工具。
  ///
  /// 如果同名工具已存在，会覆盖旧实例。
  void register(ToolBase tool) {
    _tools[tool.name] = tool;
  }

  /// 注销一个工具。
  ///
  /// 如果工具不存在，静默忽略。
  void unregister(String name) {
    _tools.remove(name);
    _disabledTools.remove(name);
  }

  /// 获取指定名称的工具实例。
  ///
  /// 如果工具不存在或已被禁用，返回 `null`。
  ToolBase? getTool(String name) {
    if (_disabledTools.contains(name)) return null;
    return _tools[name];
  }

  /// 获取所有已注册的工具（不含已禁用的）。
  List<ToolBase> getAllTools() {
    return _tools.values
        .where((tool) => !_disabledTools.contains(tool.name))
        .toList();
  }

  /// 获取所有已注册的工具名称（含已禁用的）。
  List<String> getAllToolNames() {
    return _tools.keys.toList();
  }

  /// 获取所有**已启用**的工具名称。
  List<String> getEnabledToolNames() {
    return _tools.keys
        .where((name) => !_disabledTools.contains(name))
        .toList();
  }

  /// 获取所有已禁用的工具名称。
  List<String> getDisabledToolNames() {
    return _disabledTools.toList();
  }

  /// 设置工具的启用/禁用状态。
  ///
  /// - [name] 工具名称
  /// - [enabled] `true` 启用，`false` 禁用
  ///
  /// 如果工具不存在，调用无效果。
  void setToolEnabled(String name, bool enabled) {
    if (!_tools.containsKey(name)) return;
    if (enabled) {
      _disabledTools.remove(name);
    } else {
      _disabledTools.add(name);
    }
  }

  /// 启用指定工具（[setToolEnabled] 的便捷方法）。
  void enableTool(String name) => setToolEnabled(name, true);

  /// 禁用指定工具（[setToolEnabled] 的便捷方法）。
  void disableTool(String name) => setToolEnabled(name, false);

  /// 获取所有**已启用**工具的 OpenAI function calling 格式定义列表。
  ///
  /// 返回格式示例：
  /// ```json
  /// [
  ///   {
  ///     "type": "function",
  ///     "function": {
  ///       "name": "web_search",
  ///       "description": "...",
  ///       "parameters": {...}
  ///     }
  ///   },
  ///   ...
  /// ]
  /// ```
  List<Map<String, dynamic>> getFunctionDefinitions() {
    return getAllTools()
        .map((tool) => tool.toFunctionDefinition())
        .toList();
  }

  /// 检查工具是否已注册（无论启用/禁用）。
  bool hasTool(String name) => _tools.containsKey(name);

  /// 检查工具是否已启用。
  bool isToolEnabled(String name) {
    return _tools.containsKey(name) && !_disabledTools.contains(name);
  }

  /// 已注册工具数量（不含已禁用的）。
  int get enabledCount => getAllTools().length;

  /// 总注册工具数量（含已禁用的）。
  int get totalCount => _tools.length;

  /// 清空所有注册信息。
  void clear() {
    _tools.clear();
    _disabledTools.clear();
  }

  @override
  String toString() =>
      'ToolRegistry(enabled: $enabledCount, total: $totalCount)';
}

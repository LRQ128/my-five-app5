/// 日历工具（手机本地功能示例）。
///
/// 提供查询日历日程的能力。
/// 当前为占位实现，实际需要 Platform Channel 调用 Android 原生接口。
library calendar_tool;

import 'tool_base.dart';

/// 日历工具
class CalendarTool extends ToolBase {
  CalendarTool()
      : super(
          name: 'query_calendar',
          description: '查询手机日历日程，获取指定日期的日程安排',
          parameters: const {
            'type': 'object',
            'properties': {
              'date': {
                'type': 'string',
                'description': '查询日期，格式 YYYY-MM-DD，如 "2025-01-15"',
              },
            },
            'required': ['date'],
          },
        );

  /// 验证日期格式 YYYY-MM-DD
  static final _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final String date = args['date'] as String? ?? '';

    if (date.trim().isEmpty) {
      return '错误：日期不能为空';
    }

    if (!_datePattern.hasMatch(date.trim())) {
      return '错误：日期格式不正确，请使用 YYYY-MM-DD 格式，如 "2025-01-15"';
    }

    // 解析日期以验证有效性
    final parts = date.split('-');
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return '错误：日期格式不正确，请使用 YYYY-MM-DD 格式';
    }

    if (month < 1 || month > 12) {
      return '错误：月份必须在 1-12 之间';
    }

    if (day < 1 || day > 31) {
      return '错误：日期必须在 1-31 之间';
    }

    // 占位实现——说明状态
    return '日历功能需要通过 Platform Channel 调用 Android 原生接口，当前为占位实现。'
        '\n\n'
        '【查询日期】$date\n'
        '【模拟结果】当天暂无日程安排';
  }
}

/// 备忘录工具（手机本地功能示例）。
///
/// 提供创建、查询备忘录的能力。
/// 当前为占位实现，实际需要 Platform Channel 调用 Android 原生接口。
library note_tool;

import 'tool_base.dart';

/// 备忘录工具
class NoteTool extends ToolBase {
  NoteTool()
      : super(
          name: 'create_note',
          description: '在手机上创建备忘录，保存标题和内容',
          parameters: const {
            'type': 'object',
            'properties': {
              'title': {
                'type': 'string',
                'description': '备忘录标题',
              },
              'content': {
                'type': 'string',
                'description': '备忘录正文内容',
              },
            },
            'required': ['title', 'content'],
          },
        );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final String title = args['title'] as String? ?? '';
    final String content = args['content'] as String? ?? '';

    if (title.trim().isEmpty) {
      return '错误：备忘录标题不能为空';
    }

    // 占位实现——说明状态
    return '备忘录功能需要通过 Platform Channel 调用 Android 原生接口，当前为占位实现。'
        '\n\n'
        '【模拟数据预览】\n'
        '标题：$title\n'
        '内容：$content\n'
        '状态：已记录（模拟）';
  }
}

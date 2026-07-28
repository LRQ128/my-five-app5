/// 联网搜索工具。
///
/// 通过 DuckDuckGo Instant Answer API 获取搜索结果，
/// 返回标题、摘要和链接。如果 API 不可用则返回配置提示。

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tool_base.dart';

/// 联网搜索工具
class WebSearchTool extends ToolBase {
  /// 默认的 DuckDuckGo Instant Answer API 端点
  static const String _duckDuckGoApi = 'https://api.duckduckgo.com/';

  WebSearchTool()
      : super(
          name: 'web_search',
          description: '搜索互联网获取最新信息，需要联网权限',
          parameters: const {
            'type': 'object',
            'properties': {
              'query': {
                'type': 'string',
                'description': '搜索关键词',
              },
              'num_results': {
                'type': 'integer',
                'description': '返回结果数量，默认 5',
                'default': 5,
              },
            },
            'required': ['query'],
          },
        );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final String query = args['query'] as String? ?? '';
    final int numResults = (args['num_results'] as int?) ?? 5;

    if (query.trim().isEmpty) {
      return '错误：搜索关键词不能为空';
    }

    try {
      // 尝试通过 DuckDuckGo Instant Answer API 获取结果
      final result =
          await _searchDuckDuckGo(query, numResults);
      if (result != null && result.isNotEmpty) {
        return result;
      }

      // DuckDuckGo 没有返回有效结果，尝试直接 HTML 抓取
      final htmlResult =
          await _searchDuckDuckGoHtml(query, numResults);
      if (htmlResult != null && htmlResult.isNotEmpty) {
        return htmlResult;
      }

      return '未找到与 "$query" 相关的搜索结果';
    } catch (e) {
      return '搜索服务未配置，请在设置中配置搜索 API Key。'
          '当前错误详情：${e.toString()}';
    }
  }

  /// 通过 DuckDuckGo Instant Answer API 搜索
  Future<String?> _searchDuckDuckGo(String query, int numResults) async {
    try {
      final uri = Uri.parse(_duckDuckGoApi).replace(queryParameters: {
        'q': query,
        'format': 'json',
        'no_html': '1',
        'skip_disambig': '1',
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final buffer = StringBuffer();

      // Abstract / AbstractText
      final abstractText = data['AbstractText'] as String? ?? '';
      if (abstractText.isNotEmpty) {
        final abstractSource =
            data['AbstractSource'] as String? ?? '';
        final abstractUrl = data['AbstractURL'] as String? ?? '';
        buffer.writeln('📌 摘要：$abstractText');
        if (abstractSource.isNotEmpty) {
          buffer.writeln('   来源：$abstractSource');
        }
        if (abstractUrl.isNotEmpty) {
          buffer.writeln('   链接：$abstractUrl');
        }
        buffer.writeln();
      }

      // RelatedTopics
      final relatedTopics = data['RelatedTopics'] as List<dynamic>? ?? [];
      int count = 0;
      for (final topic in relatedTopics) {
        if (topic is Map<String, dynamic>) {
          final text = topic['Text'] as String? ?? '';
          final url = topic['FirstURL'] as String? ?? '';
          if (text.isNotEmpty) {
            buffer.writeln('🔗 ${text.replaceAll(RegExp(r'<[^>]*>'), '')}');
            if (url.isNotEmpty) {
              buffer.writeln('   链接：$url');
            }
            buffer.writeln();
            count++;
            if (count >= numResults) break;
          }
        }
      }

      // Infobox（如果存在）
      final infobox = data['Infobox'] as Map<String, dynamic>?;
      if (infobox != null && infobox.isNotEmpty) {
        buffer.writeln('--- 知识卡片 ---');
        for (final entry in infobox.entries) {
          buffer.writeln('${entry.key}: ${entry.value}');
        }
        buffer.writeln();
      }

      return buffer.toString().trim().isNotEmpty ? buffer.toString().trim() : null;
    } catch (_) {
      return null;
    }
  }

  /// 通过 DuckDuckGo HTML 页面搜索（兜底方案）
  Future<String?> _searchDuckDuckGoHtml(
    String query,
    int numResults,
  ) async {
    try {
      final uri = Uri.parse('https://html.duckduckgo.com/html/')
          .replace(queryParameters: {'q': query});

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return null;

      final body = response.body;
      // 简单解析 HTML 结果链接
      final resultPattern = RegExp(
        r'<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
        dotAll: true,
      );

      final matches = resultPattern.allMatches(body);
      if (matches.isEmpty) return null;

      final buffer = StringBuffer();
      int count = 0;
      for (final match in matches) {
        final url = match.group(1) ?? '';
        final title = match.group(2)?.replaceAll(RegExp(r'<[^>]*>'), '') ?? '';
        if (title.isNotEmpty) {
          buffer.writeln('🔗 $title');
          if (url.isNotEmpty) {
            buffer.writeln('   链接：$url');
          }
          buffer.writeln();
          count++;
          if (count >= numResults) break;
        }
      }

      return buffer.toString().trim().isNotEmpty ? buffer.toString().trim() : null;
    } catch (_) {
      return null;
    }
  }
}

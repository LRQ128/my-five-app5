/// 天气查询工具。
///
/// 通过 wttr.in 公开 API 获取天气信息，支持指定地点和天数（1-7 天）。
/// 无需 API Key。

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tool_base.dart';

/// 天气查询工具
class WeatherTool extends ToolBase {
  /// wttr.in API 基础地址
  static const String _wttrBase = 'https://wttr.in';

  WeatherTool()
      : super(
          name: 'weather',
          description: '查询天气信息，返回温度、湿度、风力、天气状况等数据',
          parameters: const {
            'type': 'object',
            'properties': {
              'location': {
                'type': 'string',
                'description': '地点名称，如 "Beijing"、"上海"、"Tokyo"',
              },
              'days': {
                'type': 'integer',
                'description': '查询天数，范围 1-7，默认 1',
                'default': 1,
                'minimum': 1,
                'maximum': 7,
              },
            },
            'required': ['location'],
          },
        );

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final String location = args['location'] as String? ?? '';
    final int days = (args['days'] as int?) ?? 1;

    if (location.trim().isEmpty) {
      return '错误：地点不能为空';
    }

    final clampedDays = days.clamp(1, 7);

    try {
      // 获取当前天气（JSON 格式）
      final currentWeather = await _fetchCurrentWeather(location);

      // 如果多天预报，获取预报数据
      String forecast = '';
      if (clampedDays > 1) {
        forecast = await _fetchForecast(location, clampedDays);
      }

      if (currentWeather.isEmpty && forecast.isEmpty) {
        return '无法获取 "$location" 的天气数据，请检查地点名称是否正确';
      }

      final buffer = StringBuffer();
      buffer.writeln('🌤️ $location 天气：');
      buffer.writeln(currentWeather);
      if (forecast.isNotEmpty) {
        buffer.writeln();
        buffer.writeln(forecast);
      }

      return buffer.toString().trim();
    } catch (e) {
      return '天气查询失败：网络连接错误，请检查网络设置。详情：${e.toString()}';
    }
  }

  /// 获取当前天气（纯文本格式）
  Future<String> _fetchCurrentWeather(String location) async {
    try {
      final uri = Uri.parse('$_wttrBase/${Uri.encodeComponent(location)}')
          .replace(queryParameters: {
        'format': 'j1', // JSON 格式
        'lang': 'zh', // 中文
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return '';

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _formatCurrentWeather(data);
    } catch (_) {
      // 降级为纯文本格式
      return await _fetchCurrentWeatherPlain(location);
    }
  }

  /// 格式化当前天气 JSON 数据
  String _formatCurrentWeather(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    try {
      final currentCondition =
          data['current_condition'] as List<dynamic>?;
      if (currentCondition != null && currentCondition.isNotEmpty) {
        final c = currentCondition[0] as Map<String, dynamic>;
        buffer.writeln(
          '🌡️ 温度：${c['temp_C']}°C（体感 ${c['FeelsLikeC']}°C）',
        );
        buffer.writeln('☁️ 天气：${c['weatherDesc'] is List ? (c['weatherDesc'] as List)[0]['value'] ?? '' : c['weatherDesc'] ?? ''}');
        buffer.writeln('💧 湿度：${c['humidity']}%');
        buffer.writeln('🌬️ 风力：${c['winddir16Point']} ${c['windspeedKmph']} km/h');
        buffer.writeln('👁️ 能见度：${c['visibility']} km');
        buffer.writeln('📊 气压：${c['pressure']} hPa');
        buffer.writeln('🌞 紫外线指数：${c['uvIndex']}');
      }

      // 最近几天的预报摘要
      final weather = data['weather'] as List<dynamic>?;
      if (weather != null && weather.isNotEmpty) {
        final today = weather[0] as Map<String, dynamic>;
        buffer.writeln('🌅 日出：${today['astronomy']?[0]['sunrise'] ?? 'N/A'}');
        buffer.writeln('🌇 日落：${today['astronomy']?[0]['sunset'] ?? 'N/A'}');
        buffer.writeln('📈 最高温：${today['maxtempC']}°C');
        buffer.writeln('📉 最低温：${today['mintempC']}°C');
      }

      return buffer.toString().trim();
    } catch (_) {
      return '天气数据解析异常，请稍后重试';
    }
  }

  /// 降级方案：纯文本格式
  Future<String> _fetchCurrentWeatherPlain(String location) async {
    try {
      final uri = Uri.parse('$_wttrBase/${Uri.encodeComponent(location)}')
          .replace(queryParameters: {
        'format': '3', // 简洁文本格式
        'lang': 'zh',
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return '';
      return response.body.trim();
    } catch (_) {
      return '';
    }
  }

  /// 获取多天预报
  Future<String> _fetchForecast(String location, int days) async {
    try {
      final uri = Uri.parse('$_wttrBase/${Uri.encodeComponent(location)}')
          .replace(queryParameters: {
        'format': 'j1',
        'lang': 'zh',
      });

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return '';

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final weather = data['weather'] as List<dynamic>?;
      if (weather == null || weather.isEmpty) return '';

      final buffer = StringBuffer();
      buffer.writeln('📅 未来 $days 天预报：');
      buffer.writeln('─' * 25);

      for (int i = 0; i < days && i < weather.length; i++) {
        final day = weather[i] as Map<String, dynamic>;
        final date = day['date'] ?? '';
        final maxTemp = day['maxtempC'] ?? '';
        final minTemp = day['mintempC'] ?? '';
        final avgTemp = day['avgtempC'] ?? '';
        final sunHour = day['sunHour'] ?? '';
        final hourly = day['hourly'] as List<dynamic>?;

        buffer.writeln('📆 $date');
        buffer.writeln(
          '   🌡️ 高温 $maxTemp°C / 低温 $minTemp°C（均温 ${avgTemp}°C）',
        );

        if (hourly != null && hourly.isNotEmpty) {
          // 取中午时段（约12:00）的天气描述
          final midday = hourly.length > 4 ? hourly[4] as Map<String, dynamic> : hourly[0] as Map<String, dynamic>;
          final desc = midday['weatherDesc'] is List
              ? (midday['weatherDesc'] as List)[0]['value'] ?? ''
              : midday['weatherDesc'] ?? '';
          buffer.writeln('   ☁️ $desc');
        }

        buffer.writeln('   ☀️ 日照时长：${sunHour}h');
        buffer.writeln();
      }

      return buffer.toString().trim();
    } catch (_) {
      return '';
    }
  }
}

import 'package:flutter/material.dart';
import '../../models/model_config.dart';
import '../../utils/constants.dart';
import 'model_management.dart';

/// 设置页面——分段列表式布局
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 工具启用状态
  final Map<String, bool> _toolStates = {
    'web_search': true,
    'calculator': true,
    'code_execution': true,
    'file_read': true,
    'file_write': false,
    'shell_command': false,
    'image_generation': false,
  };

  // 通用设置
  int _contextSize = 4096;
  int _maxTokens = 2048;
  double _temperature = 0.7;
  int _threads = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.surfaceColor,
        elevation: 0,
        title: const Text(
          '设置',
          style: TextStyle(
            color: AppConstants.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(
          color: AppConstants.textSecondary,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            height: 1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 模型管理入口
          _buildSectionHeader('模型'),
          _buildModelEntry(context),

          const SizedBox(height: 24),

          // 工具管理
          _buildSectionHeader('工具管理'),
          ..._toolStates.entries.map((entry) {
            return _buildToolSwitch(context, entry.key, entry.value);
          }),

          const SizedBox(height: 24),

          // 通用设置
          _buildSectionHeader('通用设置'),
          _buildSliderSetting(
            context: context,
            title: '上下文长度',
            value: _contextSize.toDouble(),
            min: 512,
            max: 32768,
            divisions: 63,
            unit: 'tokens',
            valueFormatter: (v) => '${v.toInt()}',
            onChanged: (v) => setState(() => _contextSize = v.toInt()),
          ),
          _buildSliderSetting(
            context: context,
            title: '最大Token数',
            value: _maxTokens.toDouble(),
            min: 128,
            max: 16384,
            divisions: 127,
            unit: 'tokens',
            valueFormatter: (v) => '${v.toInt()}',
            onChanged: (v) => setState(() => _maxTokens = v.toInt()),
          ),
          _buildSliderSetting(
            context: context,
            title: '温度 (Temperature)',
            value: _temperature,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            unit: '',
            valueFormatter: (v) => v.toStringAsFixed(2),
            onChanged: (v) => setState(() => _temperature = v),
          ),
          _buildSliderSetting(
            context: context,
            title: '推理线程数',
            value: _threads.toDouble(),
            min: 1,
            max: 16,
            divisions: 15,
            unit: '线程',
            valueFormatter: (v) => '${v.toInt()}',
            onChanged: (v) => setState(() => _threads = v.toInt()),
          ),

          const SizedBox(height: 24),

          // 关于
          _buildSectionHeader('关于'),
          _buildAboutSection(context),
        ],
      ),
    );
  }

  /// Section 标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppConstants.primaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// 模型管理入口卡片
  Widget _buildModelEntry(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ModelManagementPage(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.memory,
                  color: AppConstants.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '模型管理',
                      style: TextStyle(
                        color: AppConstants.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '当前模型: Qwen2.5-7B-Q4_K_M',
                      style: TextStyle(
                        color: AppConstants.textSecondary.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppConstants.textSecondary.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 工具开关
  Widget _buildToolSwitch(BuildContext context, String toolName, bool value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: SwitchListTile(
        title: Text(
          _getToolDisplayName(toolName),
          style: const TextStyle(
            color: AppConstants.textPrimary,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          _getToolDescription(toolName),
          style: TextStyle(
            color: AppConstants.textSecondary.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        value: value,
        onChanged: (newValue) {
          setState(() {
            _toolStates[toolName] = newValue;
          });
        },
        activeColor: AppConstants.primaryColor,
        inactiveThumbColor: AppConstants.textSecondary.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  /// 滑块设置
  Widget _buildSliderSetting({
    required BuildContext context,
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required String Function(double) valueFormatter,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppConstants.textPrimary,
                  fontSize: 15,
                ),
              ),
              Text(
                '${valueFormatter(value)} $unit',
                style: TextStyle(
                  color: AppConstants.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppConstants.primaryColor,
              inactiveTrackColor: AppConstants.textSecondary.withOpacity(0.2),
              thumbColor: AppConstants.primaryColor,
              overlayColor: AppConstants.primaryColor.withOpacity(0.15),
              trackHeight: 4,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: 8,
              ),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// 关于 section
  Widget _buildAboutSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildAboutRow('应用版本', '1.0.0'),
          const Divider(
            height: 24,
            color: Color(0xFF3D3D5C),
          ),
          _buildAboutRow('开源协议', 'Apache 2.0'),
          const Divider(
            height: 24,
            color: Color(0xFF3D3D5C),
          ),
          _buildAboutRow('推理引擎', 'llama.cpp (GGUF)'),
          const Divider(
            height: 24,
            color: Color(0xFF3D3D5C),
          ),
          _buildAboutRow('默认模型', 'Qwen2.5-7B-Q4_K_M'),
          const Divider(
            height: 24,
            color: Color(0xFF3D3D5C),
          ),
          _buildAboutRow('运行平台', 'Android (Flutter)'),
        ],
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppConstants.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppConstants.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 工具显示名称
  String _getToolDisplayName(String toolName) {
    switch (toolName) {
      case 'web_search':
        return '联网搜索';
      case 'calculator':
        return '科学计算器';
      case 'code_execution':
        return '代码执行';
      case 'file_read':
        return '文件阅读';
      case 'file_write':
        return '文件写入';
      case 'shell_command':
        return '命令行执行';
      case 'image_generation':
        return '图片生成';
      default:
        return toolName;
    }
  }

  /// 工具描述
  String _getToolDescription(String toolName) {
    switch (toolName) {
      case 'web_search':
        return '允许模型联网搜索获取实时信息';
      case 'calculator':
        return '允许模型执行数学计算';
      case 'code_execution':
        return '允许模型在沙箱中执行代码';
      case 'file_read':
        return '允许模型读取本地文件';
      case 'file_write':
        return '允许模型写入本地文件';
      case 'shell_command':
        return '允许模型执行系统命令（需谨慎）';
      case 'image_generation':
        return '允许模型生成图片';
      default:
        return '';
    }
  }
}



import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../../models/model_config.dart';
import '../../services/model_manager.dart';
import '../../utils/constants.dart';

/// 模型管理页面
///
/// flutter_gemma 版本 - 点击推荐模型自动从 HuggingFace 下载安装
class ModelManagementPage extends StatefulWidget {
  final ModelManager modelManager;
  final String currentModelName;
  final ValueChanged<ModelConfig>? onModelSwitched;

  const ModelManagementPage({
    super.key,
    required this.modelManager,
    this.currentModelName = '',
    this.onModelSwitched,
  });

  @override
  State<ModelManagementPage> createState() => _ModelManagementPageState();
}

class _ModelManagementPageState extends State<ModelManagementPage> {
  /// 当前正在安装的模型ID
  String? _installingModelId;

  /// 下载进度
  double _downloadProgress = 0.0;
  String? _downloadStatus;

  @override
  void initState() {
    super.initState();
  }

  /// 将 ModelConfig id 映射到 ModelType 枚举
  ModelType _modelTypeForConfig(ModelConfig config) {
    switch (config.id) {
      case 'qwen2.5-1.5b':
        return ModelType.qwen;
      case 'phi4-mini':
        return ModelType.phi;
      case 'deepseek-r1-1.5b':
        return ModelType.deepSeek;
      case 'gemma3-1b':
        return ModelType.gemmaIt;
      case 'qwen3-0.6b':
        return ModelType.qwen3;
      case 'function-gemma-270m':
        return ModelType.functionGemma;
      default:
        return ModelType.qwen;
    }
  }

  /// 安装并加载模型
  Future<void> _installAndLoadModel(ModelConfig config) async {
    if (_installingModelId == config.id) return;

    setState(() {
      _installingModelId = config.id;
      _downloadProgress = 0;
      _downloadStatus = '准备安装...';
    });

    try {
      // 1. 安装模型（flutter_gemma 会自动下载）
      if (config.downloadUrl != null && config.downloadUrl!.isNotEmpty) {
        _downloadStatus = '正在下载模型...';

        await FlutterGemma.installModel(
          modelType: _modelTypeForConfig(config),
          fileType: ModelFileType.litertlm,
        ).fromNetwork(config.downloadUrl!).install(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _downloadProgress = progress;
              _downloadStatus =
                  '下载中... ${(progress * 100).toStringAsFixed(0)}%';
            });
          },
        );
      }

      // 3. 通过 ModelManager 加载模型
      _downloadStatus = '正在加载模型...';
      await widget.modelManager.switchModel(config);

      if (!mounted) return;
      setState(() {
        _installingModelId = null;
        _downloadProgress = 1.0;
        _downloadStatus = '模型已加载';
      });

      widget.onModelSwitched?.call(config);
      Navigator.of(context).pop(config);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _installingModelId = null;
        _downloadStatus = '安装失败: $e';
      });
      _showErrorSnackBar('模型安装失败: $e');
    }
  }

  /// 检查当前模型是否为已加载的模型
  bool _isCurrentModel(ModelConfig config) {
    final current = widget.modelManager.currentConfig;
    return current?.id == config.id && widget.modelManager.isModelLoaded;
  }

  // ---------------------------------------------------------------------------
  // UI 构建
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final availableModels = widget.modelManager.availableModels;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.surfaceColor,
        elevation: 0,
        title: const Text(
          '模型管理',
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
          // 当前加载模型卡片
          _buildCurrentModelCard(),
          const SizedBox(height: 24),

          // 可用模型列表
          _buildSectionHeader('可用模型（自动下载安装）'),
          const SizedBox(height: 8),
          ...availableModels.map((m) => _buildModelCard(context, m)),

          const SizedBox(height: 24),

          // 提示信息
          _buildInfoCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 当前加载模型卡片
  Widget _buildCurrentModelCard() {
    final current = widget.modelManager.currentConfig;
    final loaded = widget.modelManager.isModelLoaded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryColor.withOpacity(0.15),
            AppConstants.primaryColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: loaded
                  ? AppConstants.successColor.withOpacity(0.15)
                  : AppConstants.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              loaded ? Icons.check_circle : Icons.hourglass_empty,
              color: loaded
                  ? AppConstants.successColor
                  : AppConstants.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current?.name ?? '未加载模型',
                  style: const TextStyle(
                    color: AppConstants.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loaded ? '模型已加载，可以开始对话' : '请选择一个模型来下载安装',
                  style: TextStyle(
                    color: loaded
                        ? AppConstants.successColor.withOpacity(0.8)
                        : AppConstants.textSecondary.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (loaded)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppConstants.successColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check,
                      size: 14, color: AppConstants.successColor),
                  const SizedBox(width: 4),
                  const Text(
                    '已加载',
                    style: TextStyle(
                      color: AppConstants.successColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

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

  Widget _buildModelCard(BuildContext context, ModelConfig config) {
    final isCurrent = _isCurrentModel(config);
    final isInstalling = _installingModelId == config.id;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppConstants.primaryColor.withOpacity(0.08)
            : AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? AppConstants.primaryColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: isInstalling ? null : () => _installAndLoadModel(config),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.smart_toy,
                      color: isCurrent
                          ? AppConstants.primaryColor
                          : AppConstants.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name,
                          style: TextStyle(
                            color: AppConstants.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (config.description != null &&
                            config.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              config.description!,
                              style: TextStyle(
                                color: AppConstants.textSecondary
                                    .withOpacity(0.6),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isInstalling)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConstants.primaryColor,
                      ),
                    )
                  else if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppConstants.successColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '使用中',
                        style: TextStyle(
                          color: AppConstants.successColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),
              Row(
                children: [
                  _buildInfoChip(
                      Icons.memory, '${config.modelSize}'),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                      Icons.language, '${config.contextSize} ctx'),
                  if (config.supportsFunctionCalls) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(Icons.build, '函数调用'),
                  ],
                ],
              ),

              // 下载进度条
              if (isInstalling && _downloadProgress > 0 &&
                  _downloadProgress < 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        color: AppConstants.primaryColor,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _downloadStatus ?? '',
                        style: TextStyle(
                          color: AppConstants.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppConstants.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppConstants.textSecondary.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 18, color: AppConstants.accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '关于模型管理',
                  style: TextStyle(
                    color: AppConstants.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击模型名称即可自动下载并安装。\\n'
                  '模型为 .litertlm 格式，由 flutter_gemma 引擎自动管理。\\n'
                  '推荐使用 Qwen 2.5（1.5B）或 Phi-4 Mini（3.8B）。',
                  style: TextStyle(
                    color: AppConstants.textSecondary.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: AppConstants.errorColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/model_config.dart';
import '../../services/model_manager.dart';
import '../../utils/constants.dart';

// =============================================================================
// 模型管理页面
// =============================================================================

/// 模型管理页面——显示当前加载的模型、推荐模型列表、支持用户自定义添加模型。
///
/// 接受 [modelManager] 来读写可用的模型列表和切换当前模型。
/// 使用 `Navigator.pop(config)` 返回被选中的模型配置。
class ModelManagementPage extends StatefulWidget {
  /// 模型管理器实例
  final ModelManager modelManager;

  /// 当前模型名称（用于UI高亮）
  final String currentModelName;

  /// 当模型切换时的回调
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
  /// 当前正在加载的模型ID
  String? _loadingModelId;

  /// 模型加载进度
  double _downloadProgress = 0.0;

  /// 是否正在下载
  bool _isDownloading = false;

  /// 下载状态文本
  String? _downloadStatus;

  /// 已加载的模型文件路径
  String? _loadedModelPath;

  /// 可用模型列表（从 ModelManager 获取）
  late List<ModelConfig> _availableModels;

  /// 更新状态标志
  bool _needsRefresh = false;

  @override
  void initState() {
    super.initState();
    _refreshModels();
  }

  /// 从 ModelManager 刷新可用模型列表
  void _refreshModels() {
    setState(() {
      _availableModels = widget.modelManager.availableModels;
    });
  }

  /// 切换模型
  Future<void> _switchModel(ModelConfig config) async {
    if (_loadingModelId == config.id) return;

    setState(() {
      _loadingModelId = config.id;
      _isDownloading = false;
      _downloadStatus = '正在加载模型...';
    });

    try {
      await widget.modelManager.switchModel(config);

      if (!mounted) return;
      setState(() {
        _loadingModelId = null;
        _downloadStatus = '模型已加载';
      });

      // 通知父页面
      widget.onModelSwitched?.call(config);

      // 弹出并返回选中的模型
      Navigator.of(context).pop(config);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingModelId = null;
        _downloadStatus = '加载失败: $e';
      });
      _showErrorSnackBar('模型加载失败: $e');
    }
  }

  /// 从本地文件系统选取 GGUF 模型文件，添加为自定义模型
  Future<void> _pickModelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // 允许用户选 .gguf 文件
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final originalPath = file.path;

      if (originalPath == null) {
        _showErrorSnackBar('无法获取文件路径');
        return;
      }

      // 解析文件名
      final fileName = file.name;
      final modelName = fileName.replaceAll(RegExp(r'\.gguf$'), '');

      // ★ 关键修复：复制文件到 App 私有目录
      // Android SAF 返回 content:// URI，原生 C 代码 fopen() 打不开
      // 必须复制到私目录让原生代码能访问
      final appDir = await getApplicationDocumentsDirectory();
      final modelsDir = Directory('${appDir.path}/models');
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      final destPath = '${modelsDir.path}/$fileName';
      final destFile = File(destPath);

      // 如果目标已存在且大小和源一致，跳过复制
      if (await destFile.exists()) {
        final sourceFile = File(originalPath);
        try {
          final sourceLen = await sourceFile.length();
          final destLen = await destFile.length();
          if (sourceLen == destLen) {
            // 已存在且大小一致，直接使用
          } else {
            // 大小不同，重新复制
            await sourceFile.copy(destPath);
          }
        } catch (_) {
          // 读取源文件大小失败（可能是 content URI），直接复制
          await destFile.writeAsBytes(await file.bytes ?? []);
        }
      } else {
        // 尝试通过路径复制
        try {
          await File(originalPath).copy(destPath);
        } catch (_) {
          // 路径复制失败（content URI），通过 bytes 复制
          if (file.bytes != null) {
            await destFile.writeAsBytes(file.bytes!);
          } else {
            _showErrorSnackBar('无法访问文件内容');
            return;
          }
        }
      }

      // 验证复制后的文件
      if (!await destFile.exists()) {
        _showErrorSnackBar('文件复制失败，请重试');
        return;
      }

      // 生成唯一ID
      final modelId =
          'custom_${DateTime.now().millisecondsSinceEpoch}';

      // 创建新的 ModelConfig（使用复制后的路径）
      final customConfig = ModelConfig(
        id: modelId,
        name: modelName,
        filePath: destPath,
        description: '用户自定义模型: $fileName',
        isDefault: false,
      );

      // 通过 ModelManager 添加（持久化保存）
      await widget.modelManager.addModel(customConfig);

      if (!mounted) return;
      _refreshModels();

      // 自动切换到新添加的模型
      await _switchModel(customConfig);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('添加模型失败: $e');
    }
  }

  /// 删除自定义模型
  Future<void> _removeModel(ModelConfig config) async {
    try {
      await widget.modelManager.removeModel(config.id);
      if (!mounted) return;
      _refreshModels();
      _showSuccessSnackBar('已移除模型: ${config.name}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('移除失败: $e');
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
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '刷新模型列表',
            onPressed: _refreshModels,
          ),
        ],
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

          // 推荐模型列表
          _buildSectionHeader('推荐模型'),
          ..._availableModels
              .where((m) =>
                  ModelConfig.recommendedModels.any((rm) => rm.id == m.id))
              .map((m) => _buildModelCard(context, m)),

          // 自定义模型列表
          if (_availableModels.any((m) =>
              !ModelConfig.recommendedModels.any((rm) => rm.id == m.id))) ...[
            const SizedBox(height: 16),
            _buildSectionHeader('自定义模型'),
            ..._availableModels
                .where((m) =>
                    !ModelConfig.recommendedModels.any((rm) => rm.id == m.id))
                .map((m) => _buildModelCard(context, m)),
          ],

          const SizedBox(height: 24),

          // 添加模型按钮
          _buildAddModelButton(),

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
              color: loaded ? AppConstants.successColor : AppConstants.textSecondary,
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
                  loaded ? '模型已加载，可以开始对话' : '请选择一个模型来加载',
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

  /// 单个模型卡片
  Widget _buildModelCard(BuildContext context, ModelConfig config) {
    final isCurrent = _isCurrentModel(config);
    final isLoading = _loadingModelId == config.id;

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
        onTap: isLoading ? null : () => _switchModel(config),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 模型名 + 状态
              Row(
                children: [
                  // 模型图标
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
                  // 状态指示
                  if (isLoading)
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
                      child: Text(
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

              // 模型参数信息
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.memory,
                    '${(config.modelSize / 1e9).toStringAsFixed(1)}B',
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.compress,
                    config.quantization,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.token,
                    '${config.contextSize}',
                  ),
                ],
              ),

              // 删除按钮（仅自定义模型）
              if (!ModelConfig.recommendedModels
                  .any((rm) => rm.id == config.id))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _removeModel(config),
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppConstants.errorColor),
                    label: Text(
                      '删除',
                      style: TextStyle(
                        color: AppConstants.errorColor.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 参数芯片
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

  /// 添加模型按钮
  Widget _buildAddModelButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: _pickModelFile,
        icon: const Icon(Icons.add, size: 20),
        label: const Text(
          '从本地选择 .gguf 模型文件',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppConstants.primaryColor,
          side: BorderSide(
            color: AppConstants.primaryColor.withOpacity(0.4),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 提示
  // ---------------------------------------------------------------------------

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

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: AppConstants.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

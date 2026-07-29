import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/model_config.dart';
import '../../utils/constants.dart';

/// 模型管理页面
class ModelManagementPage extends StatefulWidget {
  final ModelConfig? currentModel;
  final ValueChanged<ModelConfig>? onModelChanged;

  const ModelManagementPage({
    super.key,
    this.currentModel,
    this.onModelChanged,
  });

  @override
  State<ModelManagementPage> createState() => _ModelManagementPageState();
}

class _ModelManagementPageState extends State<ModelManagementPage> {
  late ModelConfig _currentModel;
  bool _loadingModel = false;
  String? _loadingModelId;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  String? _downloadStatus;
  String? _loadedModelPath;

  @override
  void initState() {
    super.initState();
    _currentModel = widget.currentModel ??
        ModelConfig.recommendedModels.first;
  }

  Future<void> _switchModel(ModelConfig config) async {
    if (_loadingModel) return;

    setState(() {
      _loadingModel = true;
      _loadingModelId = config.id;
    });

    // 模拟模型切换延迟
    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _currentModel = config;
      _loadingModel = false;
      _loadingModelId = null;
    });

    widget.onModelChanged?.call(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已切换到 ${config.name}'),
          backgroundColor: AppConstants.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  /// 使用文件选择器选择 .gguf 模型文件
  Future<void> _pickModelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath == null) return;

        if (!filePath.endsWith('.gguf') && !filePath.endsWith('.bin')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('请选择 .gguf 格式的模型文件'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }

        // 从文件路径提取文件名作为模型名
        final modelName = filePath.split('/').last.replaceAll('.gguf', '').replaceAll('.bin', '');

        setState(() {
          _loadedModelPath = filePath;
          _currentModel = ModelConfig(
            id: 'custom_$modelName',
            name: modelName,
            filePath: filePath,
            description: '本地加载的 GGUF 模型文件',
            modelSize: File(filePath).lengthSync(),
            quantization: 'GGUF',
          );
        });

        widget.onModelChanged?.call(_currentModel);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已加载模型: $modelName'),
              backgroundColor: AppConstants.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  /// 显示添加模型对话框
  void _showAddModelDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppConstants.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '添加模型',
                style: TextStyle(
                  color: AppConstants.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildAddOption(
                icon: Icons.folder_open,
                title: '从文件选择',
                subtitle: '选择本地 .gguf 模型文件',
                onTap: () {
                  Navigator.pop(context);
                  _pickModelFile();
                },
              ),
              const SizedBox(height: 12),
              _buildAddOption(
                icon: Icons.link,
                title: 'HuggingFace 链接',
                subtitle: '输入 HuggingFace 模型下载链接',
                onTap: () {
                  Navigator.pop(context);
                  _showHuggingFaceDialog();
                },
              ),
              const SizedBox(height: 12),
              _buildAddOption(
                icon: Icons.star,
                title: '推荐模型',
                subtitle: '从推荐列表中选择已量化的模型',
                onTap: () {
                  Navigator.pop(context);
                  _showRecommendedModelsDialog();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppConstants.backgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppConstants.primaryColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppConstants.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppConstants.textSecondary.withOpacity(0.6),
                      fontSize: 12,
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
    );
  }

  void _showHuggingFaceDialog() {
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppConstants.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '输入 HuggingFace 链接',
            style: TextStyle(color: AppConstants.textPrimary, fontSize: 18),
          ),
          content: TextField(
            controller: urlController,
            style: const TextStyle(color: AppConstants.textPrimary),
            decoration: InputDecoration(
              hintText: 'https://huggingface.co/...',
              hintStyle: TextStyle(
                color: AppConstants.textSecondary.withOpacity(0.5),
              ),
              filled: true,
              fillColor: AppConstants.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '取消',
                style: TextStyle(color: AppConstants.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (urlController.text.isNotEmpty) {
                  _showDownloadInstructions(urlController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('下载'),
            ),
          ],
        );
      },
    );
  }

  void _showRecommendedModelsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppConstants.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '推荐模型',
            style: TextStyle(color: AppConstants.textPrimary, fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: ModelConfig.recommendedModels.length,
              itemBuilder: (context, index) {
                final model = ModelConfig.recommendedModels[index];
                final isLoaded = model.id == _currentModel.id;

                return ListTile(
                  leading: Icon(
                    isLoaded ? Icons.check_circle : Icons.download,
                    color: isLoaded
                        ? AppConstants.successColor
                        : AppConstants.accentColor,
                  ),
                  title: Text(
                    model.name,
                    style: const TextStyle(
                      color: AppConstants.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${model.sizeLabel} · ${model.quantization}',
                    style: TextStyle(
                      color: AppConstants.textSecondary.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  onTap: isLoaded
                      ? null
                      : () {
                          Navigator.pop(context);
                          _showDownloadInstructions(model.name);
                        },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '关闭',
                style: TextStyle(color: AppConstants.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }

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
        iconTheme: const IconThemeData(color: AppConstants.textSecondary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            height: 1,
          ),
        ),
      ),
      body: _loadingModel
          ? const Center(
              child: CircularProgressIndicator(
                color: AppConstants.primaryColor,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCurrentModelCard(),
                const SizedBox(height: 24),
                _buildAvailableModelsSection(),
                const SizedBox(height: 24),
                _buildAddModelSection(),
                const SizedBox(height: 24),
                _buildLoadedModelSection(),
              ],
            ),
    );
  }

  Widget _buildCurrentModelCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.primaryColor.withOpacity(0.3),
            AppConstants.surfaceColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.memory,
                  color: AppConstants.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前模型',
                      style: TextStyle(
                        color: AppConstants.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: AppConstants.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Text(
                      '运行中',
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
          const SizedBox(height: 16),
          Text(
            _currentModel.name,
            style: const TextStyle(
              color: AppConstants.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildInfoChip(Icons.storage, _currentModel.sizeLabel),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.memory, _currentModel.quantization),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.folder, _currentModel.filePath),
            ],
          ),
          if (_currentModel.description != null) ...[
            const SizedBox(height: 12),
            Text(
              _currentModel.description!,
              style: TextStyle(
                color: AppConstants.textSecondary.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildAvailableModelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '可用模型',
            style: TextStyle(
              color: AppConstants.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...ModelConfig.recommendedModels.map(
          (model) => _buildModelItem(model),
        ),
      ],
    );
  }

  Widget _buildModelItem(ModelConfig config) {
    final isCurrent = _currentModel.id == config.id;
    final isLoading = _loadingModelId == config.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppConstants.primaryColor.withOpacity(0.05)
            : AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? AppConstants.primaryColor.withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppConstants.primaryColor.withOpacity(0.1)
                  : AppConstants.surfaceColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.psychology,
              color: isCurrent
                  ? AppConstants.primaryColor
                  : AppConstants.textSecondary,
              size: 22,
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
                    color: isCurrent
                        ? AppConstants.primaryColor
                        : AppConstants.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildInfoChip(Icons.storage, config.sizeLabel),
                    const SizedBox(width: 6),
                    _buildInfoChip(Icons.memory, config.quantization),
                  ],
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '当前',
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            TextButton(
              onPressed: isLoading ? null : () => _switchModel(config),
              style: TextButton.styleFrom(
                foregroundColor: AppConstants.accentColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppConstants.accentColor.withOpacity(0.3),
                  ),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConstants.accentColor,
                      ),
                    )
                  : const Text(
                      '切换',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddModelSection() {
    return InkWell(
      onTap: _showAddModelDialog,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppConstants.accentColor.withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: AppConstants.accentColor.withOpacity(0.7),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '添加模型',
              style: TextStyle(
                color: AppConstants.accentColor.withOpacity(0.8),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示模型下载方式说明
  void _showDownloadInstructions(String name) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请先在浏览器下载 $name，\n再到"添加模型"→"从文件选择"加载'),
          backgroundColor: AppConstants.accentColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// 已加载的自定义模型
  Widget _buildLoadedModelSection() {
    if (_loadedModelPath == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '本地模型',
            style: TextStyle(
              color: AppConstants.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppConstants.primaryColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder,
                  color: AppConstants.primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentModel.name,
                      style: const TextStyle(
                        color: AppConstants.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _loadedModelPath ?? '',
                      style: TextStyle(
                        color: AppConstants.textSecondary.withOpacity(0.6),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, size: 14, color: AppConstants.successColor),
                    SizedBox(width: 4),
                    Text(
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
        ),
      ],
    );
  }
}

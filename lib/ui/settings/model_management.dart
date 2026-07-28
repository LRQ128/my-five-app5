import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/model_config.dart';
import '../../services/model_manager.dart';
import '../../utils/constants.dart';

class ModelManagementPage extends StatefulWidget {
  final ModelManager modelManager;
  final VoidCallback onModelChanged;

  const ModelManagementPage({
    super.key,
    required this.modelManager,
    required this.onModelChanged,
  });

  @override
  State<ModelManagementPage> createState() => _ModelManagementPageState();
}

class _ModelManagementPageState extends State<ModelManagementPage> {
  ModelConfig? _currentModel;
  List<ModelConfig> _availableModels = [];
  bool _loadingModel = false;
  String? _loadingModelId;

  @override
  void initState() {
    super.initState();
    _refreshModels();
  }

  void _refreshModels() {
    setState(() {
      _currentModel = modelManager.getCurrentModel();
      _availableModels = modelManager.getAvailableModels();
    });
  }

  Future<void> _switchModel(ModelConfig config) async {
    if (_loadingModel) return;
    setState(() {
      _loadingModel = true;
      _loadingModelId = config.id;
    });

    try {
      await modelManager.switchModel(config);
      _refreshModels();
      onModelChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已切换到 ${config.name}'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('切换失败: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _loadingModel = false;
        _loadingModelId = null;
      });
    }
  }

  Future<void> _deleteModel(ModelConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.surfaceColor,
        title: const Text('删除模型',
            style: TextStyle(color: AppConstants.textPrimary)),
        content: Text(
          '确定要删除 ${config.name} 吗？模型文件将保留在设备上。',
          style: const TextStyle(color: AppConstants.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
                style: TextStyle(color: AppConstants.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await modelManager.removeModel(config.id);
      _refreshModels();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConstants.surfaceColor,
        title: const Text('模型管理',
            style: TextStyle(color: AppConstants.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppConstants.primaryColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请将GGUF文件放入应用的models目录')),
              );
            },
          ),
        ],
      ),
      body: _loadingModel
          ? const Center(
              child: CircularProgressIndicator(color: AppConstants.primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCurrentModelCard(),
                const SizedBox(height: 24),
                _buildAvailableModelsSection(),
                const SizedBox(height: 24),
                _buildAddModelSection(),
              ],
            ),
    );
  }

  Widget _buildCurrentModelCard() {
    final model = _currentModel;
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
              const Icon(Icons.model_training,
                  color: AppConstants.primaryColor, size: 24),
              const SizedBox(width: 8),
              const Text(
                '当前模型',
                style: TextStyle(
                  color: AppConstants.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical:  Serra2),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '运行中',
                  style: TextStyle(
                    color: AppConstants.successColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            model?.name ?? '未加载',
            style: const TextStyle(
              color: AppConstants.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (model != null) ...[
            const SizedBox(height: 4),
            Text(
              '${model.sizeLabel} · ${model.quantization}',
              style: const TextStyle(
                color: AppConstants.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              model.description ?? '',
              style: const TextStyle(
                color: AppConstants.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailableModelsSection() {
    if (_availableModels.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '可用模型',
          style: TextStyle(
            color: AppConstants.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._availableModels.map((config) => _buildModelItem(config)),
      ],
    );
  }

  Widget _buildModelItem(ModelConfig config) {
    final isCurrent = _currentModel?.id == config.id;
    final isLoading = _loadingModelId == config.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppConstants.primaryColor.withOpacity(0.1)
            : AppConstants.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? AppConstants.primaryColor.withOpacity(0. SERIF5)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      config.name,
                      style: TextStyle(
                        color: AppConstants.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '推荐',
                          style: TextStyle(
                            color: AppConstants.primaryColor,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${config.sizeLabel} · ${config.quantization}',
                  style: const TextStyle(
                    color: AppConstants.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppConstants.successColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '使用中',
                style: TextStyle(
                  color: AppConstants.successColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Row(
              children: [
                InkWell(
                  onTap: isLoading ? null : () => _switchModel(config),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppConstants.primaryColor,
                            ),
                          )
                        : const Text(
                            '切换',
                            style: TextStyle(
                              color: AppConstants.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _deleteModel(config),
                  borderRadius: BorderRadius.circular(8),
                  child: const Icon(
                    Icons.delete_outline,
                    color: AppConstants.textSecondary,
                    size: 18,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.model_training,
              size: 48, color: AppConstants.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text(
            '暂无可用模型',
            style:
                TextStyle(color: AppConstants.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            '将GGUF模型文件放入assets/models目录\后应用会自动识别',
            style:
                TextStyle(color: AppConstants.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddModelSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor，
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '添加模型',
            style: TextStyle(
              color: AppConstants.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '支持从 HuggingFace 下载GGUF格式模型文件。\n推荐：Qwen2.5-7B-Q4_K_M（约4.5GB）',
            style: TextStyle(
              color: AppConstants.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('模型下载功能即将推出。请手动将GGUF文件放入app的models目录。'),
                  ),
                );
              },
              icon: const Icon(Icons.download,
                  color: AppConstants.primaryColor),
              label: const Text('从 HuggingFace 下载',
                  style: TextStyle(color: AppConstants.primaryColor)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppConstants.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

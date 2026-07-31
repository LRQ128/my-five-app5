// =============================================================================
// 模型配置 — 记录一个本地模型的参数
// =============================================================================

/// 模型配置
///
/// 描述一个可用的模型（包括推荐下载和用户自定义的）。
/// 推荐模型列表引用 flutter_gemma 支持的 .litertlm 格式模型。
class ModelConfig {
  /// 唯一标识
  final String id;

  /// 显示名称
  final String name;

  /// 模型文件路径（本地文件系统）
  final String filePath;

  /// 模型下载 URL（可选，用于从网络下载）
  final String? downloadUrl;

  /// 描述
  final String? description;

  /// 参数量（如 "1.5B"、"270M"）
  final String modelSize;

  /// 量化类型
  final String quantization;

  /// 上下文长度
  final int contextSize;

  /// 是否默认
  final bool isDefault;

  /// 温度
  final double temperature;

  /// Top-P
  final double topP;

  /// 最大 Token
  final int maxTokens;

  /// 是否支持函数调用
  final bool supportsFunctionCalls;

  /// 模型类型标识符（用于 flutter_gemma 的 installModel）
  final String? modelType;

  const ModelConfig({
    required this.id,
    required this.name,
    this.filePath = '',
    this.downloadUrl,
    this.description,
    this.modelSize = '0',
    this.quantization = 'Q4_K_M',
    this.contextSize = 4096,
    this.isDefault = false,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.maxTokens = 4096,
    this.supportsFunctionCalls = false,
    this.modelType,
  });

  // ---------------------------------------------------------------------------
  // 推荐模型列表
  //
  // 这些是 flutter_gemma 支持的模型，使用 LiteRT-LM/.litertlm 格式
  // 模型会在用户选择后自动从 HuggingFace 下载
  // ---------------------------------------------------------------------------

  static const List<ModelConfig> recommendedModels = [
    ModelConfig(
      id: 'qwen2.5-1.5b',
      name: 'Qwen 2.5',
      description: '阿里 Qwen2.5 1.5B 指令模型，中文支持好',
      modelSize: '1.5B',
      quantization: 'F16',
      contextSize: 8192,
      maxTokens: 4096,
      isDefault: true,
      supportsFunctionCalls: false,
      downloadUrl:
          'https://hf-mirror.com/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv4096.litertlm',
    ),
    ModelConfig(
      id: 'phi4-mini',
      name: 'Phi-4 Mini',
      description: '微软 Phi-4 Mini 3.8B 轻量模型',
      modelSize: '3.8B',
      quantization: 'F16',
      contextSize: 8192,
      maxTokens: 4096,
      downloadUrl:
          'https://hf-mirror.com/litert-community/Phi-4-mini-instruct/resolve/main/Phi-4-mini-instruct_multi-prefill-seq_q8_ekv4096.litertlm',
    ),
    ModelConfig(
      id: 'deepseek-r1-1.5b',
      name: 'DeepSeek R1',
      description: 'DeepSeek R1 蒸馏 Qwen 1.5B 推理模型',
      modelSize: '1.5B',
      quantization: 'F16',
      contextSize: 8192,
      maxTokens: 4096,
      downloadUrl:
          'https://hf-mirror.com/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv4096.litertlm',
    ),
    ModelConfig(
      id: 'gemma3-1b',
      name: 'Gemma 3 Nano',
      description: 'Google Gemma 3 1B 指令模型',
      modelSize: '1B',
      quantization: 'F16',
      contextSize: 8192,
      maxTokens: 4096,
      downloadUrl:
          'https://hf-mirror.com/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q8_ekv8192.litertlm',
    ),
    ModelConfig(
      id: 'qwen3-0.6b',
      name: 'Qwen3',
      description: '阿里 Qwen3 0.6B 超轻量模型',
      modelSize: '0.6B',
      quantization: 'F16',
      contextSize: 8192,
      maxTokens: 4096,
      downloadUrl:
          'https://hf-mirror.com/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_multi-prefill-seq_q8_ekv8192.litertlm',
    ),
    ModelConfig(
      id: 'function-gemma-270m',
      name: 'FunctionGemma',
      description: 'Google FunctionGemma 270M 函数调用模型',
      modelSize: '270M',
      quantization: 'F16',
      contextSize: 4096,
      maxTokens: 2048,
      supportsFunctionCalls: true,
      downloadUrl:
          'https://hf-mirror.com/sasha-denisov/function-gemma-270M-it/resolve/main/function-gemma-270M-it_q8_ekv2560.task',
    ),
  ];

  // ---------------------------------------------------------------------------
  // 序列化
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'downloadUrl': downloadUrl,
      'description': description,
      'modelSize': modelSize,
      'quantization': quantization,
      'contextSize': contextSize,
      'isDefault': isDefault,
      'temperature': temperature,
      'topP': topP,
      'maxTokens': maxTokens,
      'supportsFunctionCalls': supportsFunctionCalls,
      'modelType': modelType,
    };
  }

  factory ModelConfig.fromMap(Map<String, dynamic> map) {
    return ModelConfig(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      filePath: map['filePath'] as String? ?? '',
      downloadUrl: map['downloadUrl'] as String?,
      description: map['description'] as String?,
      modelSize: map['modelSize'] as String? ?? '0',
      quantization: map['quantization'] as String? ?? 'Q4_K_M',
      contextSize: map['contextSize'] as int? ?? 4096,
      isDefault: map['isDefault'] as bool? ?? false,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (map['topP'] as num?)?.toDouble() ?? 0.9,
      maxTokens: map['maxTokens'] as int? ?? 4096,
      supportsFunctionCalls:
          map['supportsFunctionCalls'] as bool? ?? false,
      modelType: map['modelType'] as String?,
    );
  }
}

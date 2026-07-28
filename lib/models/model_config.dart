/// 模型配置——支持热切换、多模型管理
class ModelConfig {
  final String id;
  final String name;
  final String filePath;
  final String? description;
  final int contextSize;
  final int maxTokens;
  final double temperature;
  final double topP;
  final int threads;
  final bool isDefault;
  final int modelSize; // 参数规模，如 7_000_000_000
  final String quantization; // Q4_K_M, Q8_0 等

  const ModelConfig({
    required this.id,
    required this.name,
    required this.filePath,
    this.description,
    this.contextSize = 4096,
    this.maxTokens = 2048,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.threads = 4,
    this.isDefault = false,
    this.modelSize = 7_000_000_000,
    this.quantization = 'Q4_K_M',
  });

  ModelConfig copyWith({
    String? id,
    String? name,
    String? filePath,
    String? description,
    int? contextSize,
    int? maxTokens,
    double? temperature,
    double? topP,
    int? threads,
    bool? isDefault,
    int? modelSize,
    String? quantization,
  }) {
    return ModelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      filePath: filePath ?? this.filePath,
      description: description ?? this.description,
      contextSize: contextSize ?? this.contextSize,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      threads: threads ?? this.threads,
      isDefault: isDefault ?? this.isDefault,
      modelSize: modelSize ?? this.modelSize,
      quantization: quantization ?? this.quantization,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'filePath': filePath,
        'description': description,
        'contextSize': contextSize,
        'maxTokens': maxTokens,
        'temperature': temperature,
        'topP': topP,
        'threads': threads,
        'isDefault': isDefault,
        'modelSize': modelSize,
        'quantization': quantization,
      };

  factory ModelConfig.fromMap(Map<String, dynamic> map) => ModelConfig(
        id: map['id'] as String,
        name: map['name'] as String,
        filePath: map['filePath'] as String,
        description: map['description'] as String?,
        contextSize: (map['contextSize'] as num?)?.toInt() ?? 4096,
        maxTokens: (map['maxTokens'] as num?)?.toInt() ?? 2048,
        temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
        topP: (map['topP'] as num?)?.toDouble() ?? 0.9,
        threads: (map['threads'] as num?)?.toInt() ?? 4,
        isDefault: (map['isDefault'] as bool?) ?? false,
        modelSize: (map['modelSize'] as num?)?.toInt() ?? 7_000_000_000,
        quantization: (map['quantization'] as String?) ?? 'Q4_K_M',
      );

  /// 模型大小标签
  String get sizeLabel {
    if (modelSize >= 70_000_000_000) return '70B';
    if (modelSize >= 30_000_000_000) return '30B';
    if (modelSize >= 13_000_000_000) return '14B';
    if (modelSize >= 7_000_000_000) return '7B';
    if (modelSize >= 3_000_000_000) return '3B';
    return '1.5B';
  }

  /// 推荐模型配置
  static const List<ModelConfig> recommendedModels = [
    ModelConfig(
      id: 'qwen2.5-7b-q4',
      name: 'Qwen2.5-7B-Q4_K_M',
      filePath: 'qwen2.5-7b-q4_k_m.gguf',
      description: '阿里通义千问2.5 7B版，Q4量化，约4.5GB内存',
      modelSize: 7_000_000_000,
      quantization: 'Q4_K_M',
      isDefault: true,
    ),
    ModelConfig(
      id: 'qwen2.5-14b-q4',
      name: 'Qwen2.5-14B-Q4_K_M',
      filePath: 'qwen2.5-14b-q4_k_m.gguf',
      description: '阿里通义千问2.5 14B版，Q4量化，约8.5GB内存',
      modelSize: 14_000_000_000,
      quantization: 'Q4_K_M',
    ),
    ModelConfig(
      id: 'qwen2.5-7b-q8',
      name: 'Qwen2.5-7B-Q8_0',
      filePath: 'qwen2.5-7b-q8_0.gguf',
      description: '阿里通义千问2.5 7B版，Q8量化，约7GB内存',
      modelSize: 7_000_000_000,
      quantization: 'Q8_0',
    ),
    ModelConfig(
      id: 'llama3.2-3b-q4',
      name: 'Llama-3.2-3B-Q4_K_M',
      filePath: 'llama-3.2-3b-q4_k_m.gguf',
      description: 'Meta Llama 3.2 3B版，Q4量化，约2GB内存',
      modelSize: 3_000_000_000,
      quantization: 'Q4_K_M',
    ),
  ];
}

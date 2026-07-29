import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/model_config.dart';
import 'llm_service.dart';
import 'memory_service.dart';

// =============================================================================
// ModelManager —— 多模型管理（单例）
// =============================================================================

/// 模型管理器——支持多模型热切换。
///
/// 维护当前 LlmService 实例和 ModelConfig 列表。
/// 从 SharedPreferences 持久化当前选中的模型配置和自定义模型列表。
///
/// 使用方式：
/// ```dart
/// final manager = ModelManager();
/// await manager.init(); // 初始化（加载持久化配置）
/// manager.switchModel(config); // 热切换模型
/// ```
class ModelManager {
  // ---------------------------------------------------------------------------
  // 单例
  // ---------------------------------------------------------------------------
  static final ModelManager _instance = ModelManager._internal();

  /// 注入记忆服务
  void injectMemoryService(MemoryService service) {
    _memoryService = service;
  }

  factory ModelManager() => _instance;

  ModelManager._internal();

  // ---------------------------------------------------------------------------
  // 状态
  // ---------------------------------------------------------------------------

  /// 当前 LLM 服务实例
  LlmService? _llmService;
  MemoryService? _memoryService;

  /// 当前选中的模型配置
  ModelConfig? _currentConfig;

  /// 可用模型列表
  List<ModelConfig> _availableModels = [];

  /// 是否已初始化
  bool _initialized = false;

  /// SharedPreferences keys
  static const String _prefsKeyCurrentModel = 'current_model_config';
  static const String _prefsKeyCustomModels = 'custom_models_list';

  // ---------------------------------------------------------------------------
  // Getter
  // ---------------------------------------------------------------------------

  /// 当前 LLM 服务实例
  LlmService? get llmService => _llmService;

  /// 当前模型配置
  ModelConfig? get currentConfig => _currentConfig;

  /// 可用模型列表
  List<ModelConfig> get availableModels => List.unmodifiable(_availableModels);

  /// 是否已加载模型
  bool get isModelLoaded => _llmService?.isModelLoaded ?? false;

  // ---------------------------------------------------------------------------
  // 内置推荐模型列表
  // ---------------------------------------------------------------------------

  /// 内置推荐模型列表（引用 ModelConfig.recommendedModels）
  static List<ModelConfig> get builtinModels =>
      List.unmodifiable(ModelConfig.recommendedModels);

  // ---------------------------------------------------------------------------
  // 初始化
  // ---------------------------------------------------------------------------

  /// 初始化管理器：加载持久化的配置，恢复上次使用的模型
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();

    // 1. 恢复自定义模型列表
    final customModels = await _loadCustomModels(prefs);

    // 2. 合并可用模型列表（内置 + 自定义）
    _availableModels = List.from(ModelConfig.recommendedModels);
    for (final custom in customModels) {
      // 去重：如果已有同 id 的内置模型则跳过
      final exists = _availableModels.any((m) => m.id == custom.id);
      if (!exists) {
        _availableModels.add(custom);
      }
    }

    // 3. 从 SharedPreferences 加载上次使用的模型
    final configJson = prefs.getString(_prefsKeyCurrentModel);

    if (configJson != null) {
      try {
        final configMap = jsonDecode(configJson) as Map<String, dynamic>;
        _currentConfig = ModelConfig.fromMap(configMap);
      } catch (e) {
        _currentConfig = _getDefaultModel();
      }
    } else {
      _currentConfig = _getDefaultModel();
    }

    // 4. 初始化 LlmService
    _llmService = LlamaCppService(memoryService: _memoryService);

    _initialized = true;
  }

  // ---------------------------------------------------------------------------
  // 自定义模型持久化
  // ---------------------------------------------------------------------------

  /// 从 SharedPreferences 加载自定义模型列表
  Future<List<ModelConfig>> _loadCustomModels(SharedPreferences prefs) async {
    final jsonStr = prefs.getString(_prefsKeyCustomModels);
    if (jsonStr == null) return [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => ModelConfig.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 保存自定义模型列表到 SharedPreferences
  Future<void> _saveCustomModels() async {
    final prefs = await SharedPreferences.getInstance();
    // 只保存不在内置列表中的模型
    final customModels = _availableModels.where((m) {
      return !ModelConfig.recommendedModels.any((rm) => rm.id == m.id);
    }).toList();

    final jsonStr = jsonEncode(customModels.map((m) => m.toMap()).toList());
    await prefs.setString(_prefsKeyCustomModels, jsonStr);
  }

  // ---------------------------------------------------------------------------
  // 模型加载 / 卸载
  // ---------------------------------------------------------------------------

  /// 加载模型到内存
  Future<void> loadModel(ModelConfig config) async {
    if (_llmService == null) {
      throw Exception('ModelManager 尚未初始化，请先调用 init()');
    }

    if (_llmService!.isModelLoaded) {
      await _llmService!.unloadModel();
    }

    await _llmService!.loadModel(config);
    _currentConfig = config;

    // 持久化当前选择
    await _persistCurrentConfig(config);
  }

  /// 卸载当前模型，释放资源
  Future<void> unloadModel() async {
    if (_llmService != null && _llmService!.isModelLoaded) {
      await _llmService!.unloadModel();
    }
  }

  // ---------------------------------------------------------------------------
  // 模型切换
  // ---------------------------------------------------------------------------

  /// 热切换到指定模型
  ///
  /// 如果当前已加载模型，会先卸载旧模型，再加载新模型。
  Future<void> switchModel(ModelConfig config) async {
    if (_llmService == null) {
      throw Exception('ModelManager 尚未初始化');
    }

    // 如果切换为同一个模型，无需操作
    if (_currentConfig?.id == config.id && _llmService!.isModelLoaded) {
      return;
    }

    await loadModel(config);
  }

  /// 获取当前模型配置
  ModelConfig? getCurrentModel() => _currentConfig;

  /// 获取所有可用模型
  List<ModelConfig> getAvailableModels() => List.unmodifiable(_availableModels);

  // ---------------------------------------------------------------------------
  // 模型增删
  // ---------------------------------------------------------------------------

  /// 添加自定义模型配置（持久化保存）
  Future<void> addModel(ModelConfig config) async {
    // 检查是否已存在
    final existingIndex =
        _availableModels.indexWhere((m) => m.id == config.id);
    if (existingIndex >= 0) {
      _availableModels[existingIndex] = config;
    } else {
      _availableModels.add(config);
    }
    // 持久化
    await _saveCustomModels();
  }

  /// 移除指定模型配置（不能移除当前加载的模型）
  Future<void> removeModel(String id) async {
    if (_currentConfig?.id == id && isModelLoaded) {
      throw Exception('不能移除当前正在使用的模型，请先切换到其他模型');
    }
    _availableModels.removeWhere((m) => m.id == id);
    // 持久化
    await _saveCustomModels();
  }

  // ---------------------------------------------------------------------------
  // 持久化
  // ---------------------------------------------------------------------------

  /// 持久化当前模型配置到 SharedPreferences
  Future<void> _persistCurrentConfig(ModelConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKeyCurrentModel,
      jsonEncode(config.toMap()),
    );
  }

  /// 清除持久化的模型配置
  Future<void> clearPersistedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyCurrentModel);
    await prefs.remove(_prefsKeyCustomModels);
  }

  // ---------------------------------------------------------------------------
  // 辅助
  // ---------------------------------------------------------------------------

  /// 获取默认模型配置
  ModelConfig _getDefaultModel() {
    final defaultModels =
        ModelConfig.recommendedModels.where((m) => m.isDefault).toList();
    if (defaultModels.isNotEmpty) {
      return defaultModels.first;
    }
    // 回退到第一个推荐模型
    if (ModelConfig.recommendedModels.isNotEmpty) {
      return ModelConfig.recommendedModels.first;
    }
    throw Exception('没有可用的模型配置');
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_llmService != null) {
      await unloadModel();
      _llmService = null;
    }
    _currentConfig = null;
    _initialized = false;
  }
}

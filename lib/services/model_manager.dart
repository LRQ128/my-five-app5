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
/// 从 SharedPreferences 持久化当前选中的模型配置。
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

  /// SharedPreferences key
  static const String _prefsKeyCurrentModel = 'current_model_config';

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

    // 初始化可用模型列表（合并内置模型和用户添加的模型）
    _availableModels = List.from(ModelConfig.recommendedModels);

    // 从 SharedPreferences 加载上次使用的模型
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_prefsKeyCurrentModel);

    if (configJson != null) {
      try {
        final configMap = jsonDecode(configJson) as Map<String, dynamic>;
        _currentConfig = ModelConfig.fromMap(configMap);
      } catch (e) {
        // 配置解析失败，使用默认模型
        _currentConfig = _getDefaultModel();
      }
    } else {
      _currentConfig = _getDefaultModel();
    }

    // 初始化 LlmService
    _llmService = LlamaCppService(memoryService: _memoryService);

    _initialized = true;
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
  // 模型增删（预留接口）
  // ---------------------------------------------------------------------------

  /// 添加自定义模型配置
  void addModel(ModelConfig config) {
    // 检查是否已存在
    final existingIndex =
        _availableModels.indexWhere((m) => m.id == config.id);
    if (existingIndex >= 0) {
      _availableModels[existingIndex] = config;
    } else {
      _availableModels.add(config);
    }
  }

  /// 移除指定模型配置（不能移除当前加载的模型）
  void removeModel(String id) {
    if (_currentConfig?.id == id && isModelLoaded) {
      throw Exception('不能移除当前正在使用的模型，请先切换到其他模型');
    }
    _availableModels.removeWhere((m) => m.id == id);
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

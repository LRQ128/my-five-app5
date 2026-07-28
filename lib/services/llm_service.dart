import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:uuid/uuid.dart';
import '../models/message.dart';
import '../models/model_config.dart';

// =============================================================================
// Native FFI 类型定义（llama.cpp C API 精简映射）
// =============================================================================

/// llama.cpp context 指针类型
typedef LlamaContext = Pointer<Void>;

/// llama.cpp 模型指针类型
typedef LlamaModel = Pointer<Void>;

/// GGML 后端类型
typedef GgmlBackend = Pointer<Void>;

// ---- 原生函数签名 ----
typedef LlamaModelLoadFromFileNative = Pointer<Void> Function(
    Pointer<Utf8> path, Pointer<Void> params);
typedef LlamaModelLoadFromFileDart = Pointer<Void> Function(
    Pointer<Utf8> path, Pointer<Void> params);

typedef LlamaNewContextWithModelNative = Pointer<Void> Function(
    Pointer<Void> model, Pointer<Void> params);
typedef LlamaNewContextWithModelDart = Pointer<Void> Function(
    Pointer<Void> model, Pointer<Void> params);

typedef LlamaFreeModelNative = Void Function(Pointer<Void> model);
typedef LlamaFreeModelDart = Void Function(Pointer<Void> model);

typedef LlamaFreeContextNative = Void Function(Pointer<Void> ctx);
typedef LlamaFreeContextDart = Void Function(Pointer<Void> ctx);

typedef LlamaModelDescNative = Pointer<Utf8> Function(Pointer<Void> model);
typedef LlamaModelDescDart = Pointer<Utf8> Function(Pointer<Void> model);

typedef LlamaModelSizeNative = Uint64 Function(Pointer<Void> model);
typedef LlamaModelSizeDart = int Function(Pointer<Void> model);

typedef LlamaGetModelNative = Pointer<Void> Function(Pointer<Void> ctx);
typedef LlamaGetModelDart = Pointer<Void> Function(Pointer<Void> ctx);

// ---- 原生 token 化 / 采样 / 解码 ----
typedef LlamaTokenizeNative = Int32 Function(
    Pointer<Void> model, Pointer<Utf8> text, Int32 textLen,
    Pointer<Int32> tokens, Int32 nMaxTokens, Int32 addBos, Int32 special);
typedef LlamaTokenizeDart = int Function(
    Pointer<Void> model, Pointer<Utf8> text, int textLen,
    Pointer<Int32> tokens, int nMaxTokens, int addBos, int special);

typedef LlamaTokenToPieceNative = Int32 Function(
    Pointer<Void> model, Int32 token, Pointer<Utf8> buf, Int32 length, Int32 lstrip);
typedef LlamaTokenToPieceDart = int Function(
    Pointer<Void> model, int token, Pointer<Utf8> buf, int length, int lstrip);

typedef LlamaTokenBosNative = Int32 Function(Pointer<Void> model);
typedef LlamaTokenBosDart = int Function(Pointer<Void> model);

typedef LlamaTokenEosNative = Int32 Function(Pointer<Void> model);
typedef LlamaTokenEosDart = int Function(Pointer<Void> model);

typedef LlamaGetVocabSizeNative = Int32 Function(Pointer<Void> model);
typedef LlamaGetVocabSizeDart = int Function(Pointer<Void> model);

typedef LlamaContextSizeNative = Uint32 Function(Pointer<Void> ctx);
typedef LlamaContextSizeDart = int Function(Pointer<Void> ctx);

typedef LlamaKVNCacheClearNative = Void Function(Pointer<Void> ctx);
typedef LlamaKVNCacheClearDart = Void Function(Pointer<Void> ctx);

typedef LlamaSampleGreedyNative = Int32 Function(
    Pointer<Void> ctx, Pointer<Void> candidates);
typedef LlamaSampleGreedyDart = int Function(
    Pointer<Void> ctx, Pointer<Void> candidates);

typedef LlamaCandidatesNewNative = Pointer<Void> Function(Pointer<Void> ctx);
typedef LlamaCandidatesNewDart = Pointer<Void> Function(Pointer<Void> ctx);

typedef LlamaCandidatesFreeNative = Void Function(Pointer<Void> candidates);
typedef LlamaCandidatesFreeDart = Void Function(Pointer<Void> candidates);

typedef LlamaCandidatesSetTemperatureNative = Void Function(
    Pointer<Void> candidates, Float temperature);
typedef LlamaCandidatesSetTemperatureDart = Void Function(
    Pointer<Void> candidates, double temperature);

typedef LlamaDecodeNative = Int32 Function(
    Pointer<Void> ctx, Pointer<Void> batch);
typedef LlamaDecodeDart = int Function(
    Pointer<Void> ctx, Pointer<Void> batch);

typedef LlamaBatchGetOneNative = Pointer<Void> Function(
    Pointer<Int32> tokens, Int32 nTokens);
typedef LlamaBatchGetOneDart = Pointer<Void> Function(
    Pointer<Int32> tokens, int nTokens);

typedef LlamaBatchFreeNative = Void Function(Pointer<Void> batch);
typedef LlamaBatchFreeDart = Void Function(Pointer<Void> batch);

typedef LlamaContextDefaultParamsNative = Pointer<Void> Function();
typedef LlamaContextDefaultParamsDart = Pointer<Void> Function();

typedef LlamaModelDefaultParamsNative = Pointer<Void> Function();
typedef LlamaModelDefaultParamsDart = Pointer<Void> Function();

// ---- 辅助函数 ----
typedef LlamaPrintTimingsNative = Pointer<Utf8> Function(Pointer<Void> ctx);
typedef LlamaPrintTimingsDart = Pointer<Utf8> Function(Pointer<Void> ctx);

// =============================================================================
// 抽象 LLM 服务接口
// =============================================================================

/// LLM 推理服务的抽象接口。
/// 支持 load / unload / generate / streamGenerate / stop。
abstract class LlmService {
  /// 是否已加载模型
  bool get isModelLoaded;

  /// 当前加载的模型配置
  ModelConfig? get currentConfig;

  /// 加载模型到内存
  Future<void> loadModel(ModelConfig config);

  /// 卸载模型，释放资源
  Future<void> unloadModel();

  /// 一次性生成完整回复
  Future<String> generate(
    String prompt, {
    List<Message>? history,
    int maxTokens,
    double? temperature,
    double? topP,
  });

  /// 流式逐 token 生成，返回 Stream<String>（每个 token 为一个事件）
  Stream<String> streamGenerate(
    String prompt, {
    List<Message>? history,
    int maxTokens,
    double? temperature,
    double? topP,
  });

  /// 带工具调用的流式生成。
  /// 返回 Stream<String>，其中特殊 token 序列包含 tool_calls 的 JSON。
  /// 格式: 正常文本 token -> {tool_call: {...}} -> 正常文本 ...
  Stream<String> generateWithTools(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
    int maxTokens,
    double? temperature,
    double? topP,
  });

  /// 停止当前推理
  void stop();
}

// =============================================================================
// llama.cpp 实现（通过 dart:ffi 调用 libllama.so）
// =============================================================================

/// llama.cpp 后端实现。
///
/// 使用 DynamicLibrary.open('libllama.so') 加载原生库，通过 FFI 调用
/// llama.cpp C API 完成模型加载与推理。
///
/// *当前阶段 generate 方法先返回模拟数据（mock），方便 UI 调试。*
/// 后续替换为真实推理：取消注释 _nativeGenerate 调用即可。
class LlamaCppService implements LlmService {
  // ---------------------------------------------------------------------------
  // FFI 绑定
  // ---------------------------------------------------------------------------
  late final DynamicLibrary _lib;
  late final LlamaModelLoadFromFileDart _llamaModelLoadFromFile;
  late final LlamaFreeModelDart _llamaFreeModel;
  late final LlamaNewContextWithModelDart _llamaNewContextWithModel;
  late final LlamaFreeContextDart _llamaFreeContext;
  late final LlamaTokenizeDart _llamaTokenize;
  late final LlamaTokenToPieceDart _llamaTokenToPiece;
  late final LlamaTokenBosDart _llamaTokenBos;
  late final LlamaTokenEosDart _llamaTokenEos;
  late final LlamaGetVocabSizeDart _llamaGetVocabSize;
  late final LlamaContextSizeDart _llamaContextSize;
  late final LlamaKVNCacheClearDart _llamaKVNCacheClear;
  late final LlamaSampleGreedyDart _llamaSampleGreedy;
  late final LlamaCandidatesNewDart _llamaCandidatesNew;
  late final LlamaCandidatesFreeDart _llamaCandidatesFree;
  late final LlamaCandidatesSetTemperatureDart _llamaCandidatesSetTemperature;
  late final LlamaDecodeDart _llamaDecode;
  late final LlamaBatchGetOneDart _llamaBatchGetOne;
  late final LlamaBatchFreeDart _llamaBatchFree;
  late final LlamaModelDescDart _llamaModelDesc;
  late final LlamaModelSizeDart _llamaModelSize;
  late final LlamaGetModelDart _llamaGetModel;
  late final LlamaContextDefaultParamsDart _llamaContextDefaultParams;
  late final LlamaModelDefaultParamsDart _llamaModelDefaultParams;

  // ---------------------------------------------------------------------------
  // 内部状态
  // ---------------------------------------------------------------------------

  @override
  bool isModelLoaded = false;

  @override
  ModelConfig? currentConfig;

  /// llama.cpp 模型指针
  Pointer<Void>? _model;

  /// llama.cpp 上下文指针
  Pointer<Void>? _context;

  /// 停止标志，用于中断推理循环
  bool _stopRequested = false;

  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // 构造 & FFI 初始化
  // ---------------------------------------------------------------------------

  LlamaCppService() {
    try {
      _lib = DynamicLibrary.open('libllama.so');
      _bindFunctions();
    } catch (e) {
      // 库加载失败不抛异常——允许 mock 模式运行
      print('[LlamaCppService] 加载 libllama.so 失败: $e，将使用 mock 模式');
    }
  }

  /// 绑定原生函数指针
  void _bindFunctions() {
    _llamaModelLoadFromFile =
        _lib.lookupFunction<LlamaModelLoadFromFileNative,
            LlamaModelLoadFromFileDart>('llama_model_load_from_file');

    _llamaFreeModel = _lib.lookupFunction<LlamaFreeModelNative,
        LlamaFreeModelDart>('llama_free_model');

    _llamaNewContextWithModel =
        _lib.lookupFunction<LlamaNewContextWithModelNative,
            LlamaNewContextWithModelDart>('llama_new_context_with_model');

    _llamaFreeContext = _lib.lookupFunction<LlamaFreeContextNative,
        LlamaFreeContextDart>('llama_free_context');

    _llamaTokenize =
        _lib.lookupFunction<LlamaTokenizeNative, LlamaTokenizeDart>(
            'llama_tokenize');

    _llamaTokenToPiece =
        _lib.lookupFunction<LlamaTokenToPieceNative,
            LlamaTokenToPieceDart>('llama_token_to_piece');

    _llamaTokenBos = _lib.lookupFunction<LlamaTokenBosNative,
        LlamaTokenBosDart>('llama_token_bos');

    _llamaTokenEos = _lib.lookupFunction<LlamaTokenEosNative,
        LlamaTokenEosDart>('llama_token_eos');

    _llamaGetVocabSize =
        _lib.lookupFunction<LlamaGetVocabSizeNative,
            LlamaGetVocabSizeDart>('llama_n_vocab');

    _llamaContextSize =
        _lib.lookupFunction<LlamaContextSizeNative,
            LlamaContextSizeDart>('llama_n_ctx');

    _llamaKVNCacheClear =
        _lib.lookupFunction<LlamaKVNCacheClearNative,
            LlamaKVNCacheClearDart>('llama_kv_cache_clear');

    _llamaSampleGreedy =
        _lib.lookupFunction<LlamaSampleGreedyNative,
            LlamaSampleGreedyDart>('llama_sample_token_greedy');

    _llamaCandidatesNew =
        _lib.lookupFunction<LlamaCandidatesNewNative,
            LlamaCandidatesNewDart>('llama_candidates_new');

    _llamaCandidatesFree =
        _lib.lookupFunction<LlamaCandidatesFreeNative,
            LlamaCandidatesFreeDart>('llama_candidates_free');

    _llamaCandidatesSetTemperature =
        _lib.lookupFunction<LlamaCandidatesSetTemperatureNative,
            LlamaCandidatesSetTemperatureDart>(
            'llama_candidates_set_temperature');

    _llamaDecode =
        _lib.lookupFunction<LlamaDecodeNative, LlamaDecodeDart>(
            'llama_decode');

    _llamaBatchGetOne =
        _lib.lookupFunction<LlamaBatchGetOneNative,
            LlamaBatchGetOneDart>('llama_batch_get_one');

    _llamaBatchFree =
        _lib.lookupFunction<LlamaBatchFreeNative, LlamaBatchFreeDart>(
            'llama_batch_free');

    _llamaModelDesc =
        _lib.lookupFunction<LlamaModelDescNative, LlamaModelDescDart>(
            'llama_model_desc');

    _llamaModelSize =
        _lib.lookupFunction<LlamaModelSizeNative, LlamaModelSizeDart>(
            'llama_model_size');

    _llamaGetModel =
        _lib.lookupFunction<LlamaGetModelNative, LlamaGetModelDart>(
            'llama_get_model');

    _llamaContextDefaultParams =
        _lib.lookupFunction<LlamaContextDefaultParamsNative,
            LlamaContextDefaultParamsDart>('llama_context_default_params');

    _llamaModelDefaultParams =
        _lib.lookupFunction<LlamaModelDefaultParamsNative,
            LlamaModelDefaultParamsDart>('llama_model_default_params');
  }

  // ---------------------------------------------------------------------------
  // 模型加载 / 卸载
  // ---------------------------------------------------------------------------

  @override
  Future<void> loadModel(ModelConfig config) async {
    if (isModelLoaded) {
      await unloadModel();
    }

    // 检查文件存在
    final file = File(config.filePath);
    if (!file.existsSync()) {
      throw Exception('模型文件不存在: ${config.filePath}');
    }

    try {
      // 使用默认参数加载模型
      final modelParams = _llamaModelDefaultParams();
      final pathPtr = config.filePath.toNativeUtf8();
      _model = _llamaModelLoadFromFile(pathPtr, modelParams);
      calloc.free(pathPtr);

      if (_model == Pointer.fromAddress(0)) {
        throw Exception('加载模型失败: 返回空指针');
      }

      // 创建上下文
      final ctxParams = _llamaContextDefaultParams();
      _context = _llamaNewContextWithModel(_model!, ctxParams);

      if (_context == Pointer.fromAddress(0)) {
        _llamaFreeModel(_model!);
        _model = null;
        throw Exception('创建推理上下文失败');
      }

      isModelLoaded = true;
      currentConfig = config;
      _stopRequested = false;
    } catch (e) {
      isModelLoaded = false;
      currentConfig = null;
      rethrow;
    }
  }

  @override
  Future<void> unloadModel() async {
    _stopRequested = true;

    if (_context != Pointer.fromAddress(0) && _context != Pointer.fromAddress(0)) {
      _llamaFreeContext(_context!);
      _context = null;
    }
    if (_model != Pointer.fromAddress(0) && _model != Pointer.fromAddress(0)) {
      _llamaFreeModel(_model!);
      _model = null;
    }

    isModelLoaded = false;
    currentConfig = null;
  }

  // ---------------------------------------------------------------------------
  // 生成（当前阶段使用 mock 数据）
  // ---------------------------------------------------------------------------

  @override
  Future<String> generate(
    String prompt, {
    List<Message>? history,
    int maxTokens = 1024,
    double? temperature,
    double? topP,
  }) async {
    // 如果模型已加载，可走真实推理；当前阶段使用 mock 数据方便 UI 调试
    // 后续替换：return _nativeGenerate(prompt, ...);
    return _mockGenerate(prompt, history: history);
  }

  @override
  Stream<String> streamGenerate(
    String prompt, {
    List<Message>? history,
    int maxTokens = 1024,
    double? temperature,
    double? topP,
  }) {
    // 当前阶段使用 mock 流式输出
    // 后续替换：return _nativeStreamGenerate(prompt, ...);
    return _mockStreamGenerate(prompt, history: history);
  }

  @override
  Stream<String> generateWithTools(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
    int maxTokens = 1024,
    double? temperature,
    double? topP,
  }) {
    // 当前阶段使用 mock 流式输出（含 tool_calls 模拟）
    return _mockStreamGenerateWithTools(prompt, history: history, tools: tools);
  }

  @override
  void stop() {
    _stopRequested = true;
  }

  // ---------------------------------------------------------------------------
  // Mock 数据生成（UI 调试用，后续替换为真实 llama.cpp 推理）
  // ---------------------------------------------------------------------------

  /// mock 一次性生成回复
  Future<String> _mockGenerate(
    String prompt, {
    List<Message>? history,
  }) async {
    // 模拟推理延迟
    await Future.delayed(const Duration(milliseconds: 800));
    return _buildMockResponse(prompt);
  }

  /// mock 流式逐 token 输出
  Stream<String> _mockStreamGenerate(
    String prompt, {
    List<Message>? history,
  }) async* {
    await Future.delayed(const Duration(milliseconds: 500));
    final response = _buildMockResponse(prompt);
    // 逐字符输出，模拟真实 token 流
    for (int i = 0; i < response.length; i++) {
      if (_stopRequested) break;
      await Future.delayed(const Duration(milliseconds: 30 + Random().nextInt(30)));
      yield response[i];
    }
  }

  /// mock 带工具调用的流式生成
  Stream<String> _mockStreamGenerateWithTools(
    String prompt, {
    List<Message>? history,
    List<Map<String, dynamic>>? tools,
  }) async* {
    await Future.delayed(const Duration(milliseconds: 500));

    // 模拟工具调用场景：如果 prompt 包含"天气"关键字，模拟调用天气工具
    if (prompt.contains('天气') && tools != null && tools.isNotEmpty) {
      // 先输出一些思考文本
      const thinking = '让我查询一下天气信息...';
      for (int i = 0; i < thinking.length; i++) {
        if (_stopRequested) break;
        await Future.delayed(const Duration(milliseconds: 25));
        yield thinking[i];
      }

      // 注入 tool_call JSON
      final toolCallId = 'call_${_uuid.v4().substring(0, 8)}';
      final toolCallJson = jsonEncode({
        'tool_calls': [
          {
            'id': toolCallId,
            'type': 'function',
            'function': {
              'name': 'get_weather',
              'arguments': jsonEncode({'city': '北京'}),
            },
          }
        ],
      });
      await Future.delayed(const Duration(milliseconds: 100));
      yield '\n$toolCallJson\n';
    } else {
      final response = _buildMockResponse(prompt);
      for (int i = 0; i < response.length; i++) {
        if (_stopRequested) break;
        await Future.delayed(const Duration(milliseconds: 25 + Random().nextInt(25)));
        yield response[i];
      }
    }
  }

  /// 构建 mock 回复文本
  String _buildMockResponse(String prompt) {
    if (prompt.isEmpty) {
      return '您好！我是本地AI助手，基于llama.cpp推理。请问有什么可以帮助您的？';
    }

    if (prompt.contains('天气')) {
      return '根据查询结果，北京今天晴，气温25-32°C，偏南风2-3级，空气质量良。适合户外活动。';
    }

    if (prompt.contains('代码') || prompt.contains('编程')) {
      return '这是一个简单的 Dart 函数示例：\n\n'
          '```dart\n'
          'void greet(String name) {\n'
          '  print("Hello, \$name!");\n'
          '}\n'
          '```\n\n'
          '需要我解释这个函数的作用吗？';
    }

    if (prompt.length < 20) {
      return '这是一个很好的问题！让我从多个角度为您分析...\n\n'
          '首先，我们需要考虑上下文和实际应用场景。'
          '基于当前信息，我建议从以下几个方面着手解决。';
    }

    return '已收到您的消息。作为本地AI助手，我正在使用llama.cpp进行推理。\n\n'
        '当前模型：${currentConfig?.name ?? "未加载"}\n'
        '（注：当前为 mock 推理模式，真实模型推理将在后续版本中启用）';
  }

  // ---------------------------------------------------------------------------
  // 真实 llama.cpp 推理（后续启用）
  // ---------------------------------------------------------------------------

  /// 完整推理（通过 FFI 调用 llama.cpp）
  // Future<String> _nativeGenerate(
  //   String prompt, {
  //   List<Message>? history,
  //   int maxTokens = 1024,
  //   double? temperature,
  //   double? topP,
  // }) async {
  //   if (!isModelLoaded || _model == null || _context == null) {
  //     throw Exception('模型未加载');
  //   }
  //
  //   final effectiveTemp = temperature ?? currentConfig?.temperature ?? 0.7;
  //   final tokens = <int>[];
  //   final promptText = _buildPromptText(prompt, history: history);
  //
  //   // Token 化
  //   final nPromptTokens = _tokenize(promptText);
  //
  //   // 逐 token 求值
  //   for (int i = 0; i < nPromptTokens.length; i++) {
  //     final batch = _llamaBatchGetOne(
  //       Pointer<Int32>.fromAddress(nPromptTokens[i].address),
  //       1,
  //     );
  //     _llamaDecode(_context!, batch);
  //     _llamaBatchFree(batch);
  //   }
  //
  //   // 生成
  //   final eosToken = _llamaTokenEos(_model!);
  //   final candidates = _llamaCandidatesNew(_context!);
  //   _llamaCandidatesSetTemperature(candidates, effectiveTemp);
  //
  //   for (int i = 0; i < maxTokens; i++) {
  //     if (_stopRequested) break;
  //
  //     final token = _llamaSampleGreedy(_context!, candidates);
  //     if (token == eosToken) break;
  //
  //     tokens.add(token);
  //
  //     // 将 token 回喂给模型
  //     final batch = _llamaBatchGetOne(
  //       Pointer<Int32>.fromAddress(token.address),
  //       1,
  //     );
  //     _llamaDecode(_context!, batch);
  //     _llamaBatchFree(batch);
  //   }
  //
  //   _llamaCandidatesFree(candidates);
  //
  //   // 解码
  //   final result = _detokenize(tokens);
  //   return result;
  // }

  /// 构建输入文本（带聊天模板）
  String _buildPromptText(
    String prompt, {
    List<Message>? history,
  }) {
    final buffer = StringBuffer();

    // 系统提示
    buffer.writeln('<|system|>');
    buffer.writeln('你是一个有帮助的AI助手，运行在本地设备上。');
    buffer.writeln('请用中文回复用户的问题。');
    buffer.writeln('</s>');

    // 历史消息
    if (history != null) {
      for (final msg in history) {
        switch (msg.role) {
          case MessageRole.user:
            buffer.writeln('<|user|>');
            buffer.writeln(msg.content);
            buffer.writeln('</s>');
            break;
          case MessageRole.assistant:
            buffer.writeln('<|assistant|>');
            buffer.writeln(msg.content);
            buffer.writeln('</s>');
            break;
          default:
            break;
        }
      }
    }

    // 当前用户输入
    buffer.writeln('<|user|>');
    buffer.writeln(prompt);
    buffer.writeln('</s>');
    buffer.writeln('<|assistant|>');

    return buffer.toString();
  }

  /// Token 化输入文本
  List<int> _tokenize(String text) {
    final model = _llamaGetModel(_context!);
    final nTokensMax = text.length + 64;
    final tokensPtr = calloc<Int32>(nTokensMax);
    final textPtr = text.toNativeUtf8();

    final nTokens = _llamaTokenize(
      model,
      textPtr,
      text.length,
      tokensPtr,
      nTokensMax,
      0, // addBos = false（模板中已处理）
      0, // special = false
    );

    calloc.free(textPtr);

    final result = <int>[];
    for (int i = 0; i < nTokens; i++) {
      result.add(tokensPtr[i]);
    }
    calloc.free(tokensPtr);
    return result;
  }

  /// 解码 token 列表为字符串
  String _detokenize(List<int> tokens) {
    final model = _llamaGetModel(_context!);
    final buffer = StringBuffer();
    final pieceBuffer = calloc<Utf8>(256);

    for (final token in tokens) {
      final len = _llamaTokenToPiece(model, token, pieceBuffer, 256, 0);
      if (len > 0) {
        buffer.write(pieceBuffer.toDartString());
      }
    }

    calloc.free(pieceBuffer);
    return buffer.toString();
 3}
}

// =============================================================================
// 辅助: Pointer<Utf8> → Dart String 扩展
// =============================================================================

/// FFI Utf8 指针扩展
extension Utf8PointerEx on Pointer<Utf8> {
  String toDartString() {
    final int length = _strlen(this);
    return String.fromCharCodes(
      List<int>.generate(length, (i) => elementAt(i).value),
    );
  }
}

int _strlen(Pointer<Utf8> ptr) {
  int len = 0;
  while (ptr.elementAt(len).value != 0) {
    len++;
  }
  return len;
}

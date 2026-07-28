import 'package:flutter/material.dart';
import 'ui/chat/chat_page.dart';
import 'services/model_manager.dart';
import 'services/conversation_service.dart';
import 'services/agent_engine.dart';
import 'services/memory_service.dart';
import 'tools/tool_registry.dart';
import 'utils/constants.dart';

class LocalAiAssistantApp extends StatefulWidget {
  const LocalAiAssistantApp({super.key});

  @override
  State<LocalAiAssistantApp> createState() => _LocalAiAssistantAppState();
}

class _LocalAiAssistantAppState extends State<LocalAiAssistantApp> {
  late final ModelManager modelManager;
  late final ConversationService conversationService;
  late final AgentEngine agentEngine;
  late final ToolRegistry toolRegistry;
  late final MemoryService memoryService;

  bool _initialized = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. 初始化工具注册中心
      toolRegistry = ToolRegistry();
      toolRegistry.registerDefaults();

      // 2. 初始化模型管理器
      modelManager = ModelManager();

      // 2a. 初始化记忆服务
      memoryService = MemoryService();
      await memoryService.init();

      // 2b. 注入记忆服务到模型管理器
      modelManager.injectMemoryService(memoryService);

      // 3. 初始化对话服务
      conversationService = ConversationService();
      await conversationService.initialize();

      // 4. 初始化Agent引擎（先传null，等模型加载后设置）
      agentEngine = AgentEngine(
        llmService: null,
      );

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _initError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppConstants.primaryColor,
        scaffoldBackgroundColor: AppConstants.backgroundColor,
        colorScheme: ColorScheme.dark(
          primary: AppConstants.primaryColor,
          secondary: AppConstants.accentColor,
          surface: AppConstants.surfaceColor,
          error: AppConstants.errorColor,
        ),
        fontFamily: 'PingFang SC',
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_initError != null) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 64, color: AppConstants.errorColor),
                const SizedBox(height: 16),
                Text(
                  '初始化失败',
                  style: const TextStyle(
                    color: AppConstants.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _initError!,
                  style: const TextStyle(
                    color: AppConstants.textSecondary,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _initError = null;
                      _initialized = false;
                    });
                    _initializeApp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppConstants.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName,
                style: const TextStyle(
                  color: AppConstants.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '正在初始化本地模型引擎...',
                style: const TextStyle(
                  color: AppConstants.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ChatPage();
  }
}

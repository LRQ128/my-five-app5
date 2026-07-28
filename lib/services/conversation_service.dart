import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';

// =============================================================================
// ConversationService —— 对话历史管理（sqflite 本地存储）
// =============================================================================

/// 对话历史管理服务。
///
/// 使用 sqflite 在本地数据库中存储对话和消息。
/// 表结构：
/// - conversations: id, title, createdAt, updatedAt, modelName, config
/// - messages: id, conversationId, role, content, status, createdAt,
///   toolCalls, metadata, errorMessage
class ConversationService {
  // ---------------------------------------------------------------------------
  // 数据库相关
  // ---------------------------------------------------------------------------

  static const String _dbName = 'local_ai_assistant.db';
  static const int _dbVersion = 1;

  Database? _db;
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------------
  // 表名与列名常量
  // ---------------------------------------------------------------------------

  static const String _tableConversations = 'conversations';
  static const String _tableMessages = 'messages';

  // conversations 表列
  static const String _colConvId = 'id';
  static const String _colConvTitle = 'title';
  static const String _colConvCreatedAt = 'createdAt';
  static const String _colConvUpdatedAt = 'updatedAt';
  static const String _colConvModelName = 'modelName';
  static const String _colConvConfig = 'config';

  // messages 表列
  static const String _colMsgId = 'id';
  static const String _colMsgConversationId = 'conversationId';
  static const String _colMsgRole = 'role';
  static const String _colMsgContent = 'content';
  static const String _colMsgStatus = 'status';
  static const String _colMsgCreatedAt = 'createdAt';
  static const String _colMsgToolCalls = 'toolCalls';
  static const String _colMsgMetadata = 'metadata';
  static const String _colMsgErrorMessage = 'errorMessage';

  // ---------------------------------------------------------------------------
  // 构造函数 & 数据库初始化
  // ---------------------------------------------------------------------------

  ConversationService();

  /// 初始化数据库（异步完成，不阻塞构造）
  Future<void> _initDatabase() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 确保数据库已初始化（用于异步等待）
  Future<Database> get _database async {
    if (_db != null) return _db!;
    await _initDatabase();
    return _db!;
  }

  // ---------------------------------------------------------------------------
  // 数据库建表
  // ---------------------------------------------------------------------------

  Future<void> _onCreate(Database db, int version) async {
    // conversations 表
    await db.execute('''
      CREATE TABLE $_tableConversations (
        $_colConvId TEXT PRIMARY KEY,
        $_colConvTitle TEXT NOT NULL DEFAULT '新对话',
        $_colConvCreatedAt TEXT NOT NULL,
        $_colConvUpdatedAt TEXT NOT NULL,
        $_colConvModelName TEXT,
        $_colConvConfig TEXT
      )
    ''');

    // messages 表
    await db.execute('''
      CREATE TABLE $_tableMessages (
        $_colMsgId TEXT PRIMARY KEY,
        $_colMsgConversationId TEXT NOT NULL,
        $_colMsgRole TEXT NOT NULL,
        $_colMsgContent TEXT NOT NULL DEFAULT '',
        $_colMsgStatus TEXT NOT NULL DEFAULT 'completed',
        $_colMsgCreatedAt TEXT NOT NULL,
        $_colMsgToolCalls TEXT,
        $_colMsgMetadata TEXT,
        $_colMsgErrorMessage TEXT,
        FOREIGN KEY ($_colMsgConversationId)
          REFERENCES $_tableConversations($_colConvId)
          ON DELETE CASCADE
      )
    ''');

    // 索引：按 conversationId 查询消息
    await db.execute('''
      CREATE INDEX idx_msg_conv_id
      ON $_tableMessages($_colMsgConversationId)
    ''');

    // 索引：按更新时间排序对话
    await db.execute('''
      CREATE INDEX idx_conv_updated
      ON $_tableConversations($_colConvUpdatedAt DESC)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 后续版本迁移在此处理
  }

  // ---------------------------------------------------------------------------
  // Conversation CRUD
  // ---------------------------------------------------------------------------

  /// 创建新对话
  Future<Conversation> createConversation({
    String? title,
    String? modelName,
    Map<String, dynamic>? config,
  }) async {
    final db = await _database;
    final now = DateTime.now();
    final id = _uuid.v4();

    final conversation = Conversation(
      id: id,
      title: title ?? '新对话',
      createdAt: now,
      updatedAt: now,
      modelName: modelName,
      config: config,
    );

    await db.insert(_tableConversations, {
      _colConvId: conversation.id,
      _colConvTitle: conversation.title,
      _colConvCreatedAt: conversation.createdAt.toIso8601String(),
      _colConvUpdatedAt: conversation.updatedAt.toIso8601String(),
      _colConvModelName: conversation.modelName,
      _colConvConfig:
          conversation.config != null ? jsonEncode(conversation.config) : null,
    });

    return conversation;
  }

  /// 删除指定对话及其所有消息
  Future<void> deleteConversation(String id) async {
    final db = await _database;
    // 先删除关联消息（外键 CASCADE 会处理，但显式删除更安全）
    await db.delete(
      _tableMessages,
      where: '$_colMsgConversationId = ?',
      whereArgs: [id],
    );
    await db.delete(
      _tableConversations,
      where: '$_colConvId = ?',
      whereArgs: [id],
    );
  }

  /// 获取所有对话（按更新时间倒序）
  Future<List<Conversation>> getAllConversations() async {
    final db = await _database;
    final maps = await db.query(
      _tableConversations,
      orderBy: '$_colConvUpdatedAt DESC',
    );

    return maps.map((map) => Conversation.fromMap({
          ...map,
          'config': map[_colConvConfig] != null
              ? jsonDecode(map[_colConvConfig] as String)
              : null,
        })).toList();
  }

  /// 获取单个对话（不含消息列表）
  Future<Conversation?> getConversation(String id) async {
    final db = await _database;
    final maps = await db.query(
      _tableConversations,
      where: '$_colConvId = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return Conversation.fromMap({
      ...map,
      'config': map[_colConvConfig] != null
          ? jsonDecode(map[_colConvConfig] as String)
          : null,
    });
  }

  /// 更新对话标题
  Future<void> updateConversationTitle(String id, String title) async {
    final db = await _database;
    await db.update(
      _tableConversations,
      {
        _colConvTitle: title,
        _colConvUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '$_colConvId = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Message CRUD
  // ---------------------------------------------------------------------------

  /// 添加消息到指定对话
  Future<void> addMessage(Message msg) async {
    final db = await _database;
    await db.insert(_tableMessages, {
      _colMsgId: msg.id,
      _colMsgConversationId: msg.conversationId,
      _colMsgRole: msg.role.toJson(),
      _colMsgContent: msg.content,
      _colMsgStatus: msg.status.name,
      _colMsgCreatedAt: msg.createdAt.toIso8601String(),
      _colMsgToolCalls: msg.toolCalls != null
          ? jsonEncode(msg.toolCalls!.map((t) => t.toMap()).toList())
          : null,
      _colMsgMetadata:
          msg.metadata != null ? jsonEncode(msg.metadata) : null,
      _colMsgErrorMessage: msg.errorMessage,
    });

    // 更新对话的 updatedAt
    await db.update(
      _tableConversations,
      {_colConvUpdatedAt: DateTime.now().toIso8601String()},
      where: '$_colConvId = ?',
      whereArgs: [msg.conversationId],
    );
  }

  /// 更新消息
  Future<void> updateMessage(Message msg) async {
    final db = await _database;
    await db.update(
      _tableMessages,
      {
        _colMsgRole: msg.role.toJson(),
        _colMsgContent: msg.content,
        _colMsgStatus: msg.status.name,
        _colMsgToolCalls: msg.toolCalls != null
            ? jsonEncode(msg.toolCalls!.map((t) => t.toMap()).toList())
            : null,
        _colMsgMetadata:
            msg.metadata != null ? jsonEncode(msg.metadata) : null,
        _colMsgErrorMessage: msg.errorMessage,
      },
      where: '$_colMsgId = ?',
      whereArgs: [msg.id],
    );
  }

  /// 获取指定对话的所有消息（按时间正序）
  Future<List<Message>> getMessages(String conversationId) async {
    final db = await _database;
    final maps = await db.query(
      _tableMessages,
      where: '$_colMsgConversationId = ?',
      whereArgs: [conversationId],
      orderBy: '$_colMsgCreatedAt ASC',
    );

    return maps.map((map) => Message.fromMap({
          ...map,
          'toolCalls': map[_colMsgToolCalls] != null
              ? jsonDecode(map[_colMsgToolCalls] as String)
              : null,
          'metadata': map[_colMsgMetadata] != null
              ? jsonDecode(map[_colMsgMetadata] as String)
              : null,
        })).toList();
  }

  /// 获取对话及其所有消息
  Future<Conversation?> getConversationWithMessages(String id) async {
    final conversation = await getConversation(id);
    if (conversation == null) return null;

    final messages = await getMessages(id);
    return conversation.copyWith(messages: messages);
  }

  /// 搜索消息（全文模糊匹配，按内容搜索）
  Future<List<Message>> searchMessages(String query) async {
    final db = await _database;
    final maps = await db.query(
      _tableMessages,
      where: '$_colMsgContent LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: '$_colMsgCreatedAt DESC',
      limit: 50,
    );

    return maps.map((map) => Message.fromMap({
          ...map,
          'toolCalls': map[_colMsgToolCalls] != null
              ? jsonDecode(map[_colMsgToolCalls] as String)
              : null,
          'metadata': map[_colMsgMetadata] != null
              ? jsonDecode(map[_colMsgMetadata] as String)
              : null,
        })).toList();
  }

  /// 获取对话的消息数量
  Future<int> getMessageCount(String conversationId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableMessages WHERE $_colMsgConversationId = ?',
      [conversationId],
    );
    final first = result.first['count'] as int?;
    return first ?? 0;
  }

  /// 清空对话的所有消息
  Future<void> clearMessages(String conversationId) async {
    final db = await _database;
    await db.delete(
      _tableMessages,
      where: '$_colMsgConversationId = ?',
      whereArgs: [conversationId],
    );
  }

  // ---------------------------------------------------------------------------
  // 批量操作
  // ---------------------------------------------------------------------------

  /// 批量添加消息
  Future<void> addMessages(List<Message> messages) async {
    final db = await _database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final msg in messages) {
      batch.insert(_tableMessages, {
        _colMsgId: msg.id,
        _colMsgConversationId: msg.conversationId,
        _colMsgRole: msg.role.toJson(),
        _colMsgContent: msg.content,
        _colMsgStatus: msg.status.name,
        _colMsgCreatedAt: msg.createdAt.toIso8601String(),
        _colMsgToolCalls: msg.toolCalls != null
            ? jsonEncode(msg.toolCalls!.map((t) => t.toMap()).toList())
            : null,
        _colMsgMetadata:
            msg.metadata != null ? jsonEncode(msg.metadata) : null,
        _colMsgErrorMessage: msg.errorMessage,
      });
    }

    await batch.commit(noResult: true);

    // 更新对话更新时间
    if (messages.isNotEmpty) {
      await db.update(
        _tableConversations,
        {_colConvUpdatedAt: now},
        where: '$_colConvId = ?',
        whereArgs: [messages.first.conversationId],
      );
    }
  }

  /// 删除旧对话（保留最近 N 个）
  Future<int> deleteOldConversations(int keepCount) async {
    final db = await _database;
    final allConvs = await getAllConversations();
    if (allConvs.length <= keepCount) return 0;

    int deleted = 0;
    final toDelete = allConvs.sublist(keepCount);
    for (final conv in toDelete) {
      await deleteConversation(conv.id);
      deleted++;
    }
    return deleted;
  }

  // ---------------------------------------------------------------------------
  // 释放资源
  // ---------------------------------------------------------------------------

  /// 初始化服务（等待数据库就绪）
  Future<void> initialize() async {
    await _initDatabase();
  }

  /// 关闭数据库连接
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

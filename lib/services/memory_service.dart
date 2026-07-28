import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 记忆项
class MemoryItem {
  final int? id;
  final String key;
  final String value;
  final String category; // 'preference', 'fact', 'feedback', 'summary'
  final DateTime createdAt;
  final DateTime updatedAt;

  MemoryItem({
    this.id,
    required this.key,
    required this.value,
    this.category = 'fact',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'key': key,
        'value': value,
        'category': category,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory MemoryItem.fromMap(Map<String, dynamic> map) => MemoryItem(
        id: map['id'] as int?,
        key: map['key'] as String,
        value: map['value'] as String,
        category: map['category'] as String? ?? 'fact',
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

/// 对话摘要（用于长对话压缩）
class ConversationSummary {
  final String conversationId;
  final String summary;
  final List<String> keyPoints;
  final DateTime lastUpdated;

  ConversationSummary({
    required this.conversationId,
    required this.summary,
    required this.keyPoints,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
}

/// 记忆服务——让 AI 有长对话记忆和自我进化能力
class MemoryService {
  Database? _db;
  static const String _tableName = 'memories';

  /// 初始化数据库
  Future<void> init() async {
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'assistant_memory.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT NOT NULL,
            value TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'fact',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_memories_category ON $_tableName(category)
        ''');
        await db.execute('''
          CREATE INDEX idx_memories_key ON $_tableName(key)
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 记忆存储
  // ---------------------------------------------------------------------------

  /// 存储一条记忆（如果 key 已存在则更新）
  Future<void> store(String key, String value, {String category = 'fact'}) async {
    final existing = await _db?.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [key],
    );

    if (existing != null && existing.isNotEmpty) {
      await _db?.update(
        _tableName,
        {
          'value': value,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'key = ?',
        whereArgs: [key],
      );
    } else {
      await _db?.insert(_tableName, MemoryItem(
        key: key,
        value: value,
        category: category,
      ).toMap());
    }
  }

  /// 批量存储记忆
  Future<void> storeAll(List<Map<String, String>> items, {String category = 'fact'}) async {
    for (final item in items) {
      await store(item['key']!, item['value']!, category: category);
    }
  }

  // ---------------------------------------------------------------------------
  // 记忆检索
  // ---------------------------------------------------------------------------

  /// 按关键字搜索相关记忆
  Future<List<MemoryItem>> search(String query, {int limit = 10}) async {
    if (_db == null) return [];
    final results = await _db!.query(
      _tableName,
      where: 'key LIKE ? OR value LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return results.map((m) => MemoryItem.fromMap(m)).toList();
  }

  /// 获取所有偏好类记忆
  Future<List<MemoryItem>> getPreferences() async {
    if (_db == null) return [];
    final results = await _db!.query(
      _tableName,
      where: 'category = ?',
      whereArgs: ['preference'],
      orderBy: 'updated_at DESC',
    );
    return results.map((m) => MemoryItem.fromMap(m)).toList();
  }

  /// 获取最近记忆
  Future<List<MemoryItem>> getRecent({int limit = 20}) async {
    if (_db == null) return [];
    final results = await _db!.query(
      _tableName,
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return results.map((m) => MemoryItem.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------------
  // 进化能力：从用户反馈中学习
  // ---------------------------------------------------------------------------

  /// 记录用户反馈（纠错/偏好）
  Future<void> learnFromFeedback(String feedback) async {
    final prefs = await SharedPreferences.getInstance();
    final feedbacks = prefs.getStringList('user_feedbacks') ?? [];
    feedbacks.insert(0, '${DateTime.now().toIso8601String()}|$feedback');
    if (feedbacks.length > 50) feedbacks.removeRange(50, feedbacks.length);
    await prefs.setStringList('user_feedbacks', feedbacks);
  }

  /// 获取历史反馈（用于进化分析）
  Future<List<String>> getFeedbacks({int limit = 10}) async {
    final prefs = await SharedPreferences.getInstance();
    final feedbacks = prefs.getStringList('user_feedbacks') ?? [];
    return feedbacks.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // 为系统提示构建记忆上下文
  // ---------------------------------------------------------------------------

  /// 为当前对话构建记忆上下文（注入到 system prompt）
  Future<String> buildMemoryContext(String currentQuery) async {
    final buffer = StringBuffer();

    // 1. 用户偏好
    final prefs = await getPreferences();
    if (prefs.isNotEmpty) {
      buffer.writeln('\n【我对用户的了解】');
      for (final p in prefs) {
        buffer.writeln('- $p.value');
      }
    }

    // 2. 当前问题相关的记忆
    final relevant = await search(currentQuery, limit: 3);
    if (relevant.isNotEmpty) {
      buffer.writeln('\n【相关历史记忆】');
      for (final r in relevant) {
        buffer.writeln('- $r.value');
      }
    }

    // 3. 最近对话摘要
    final recent = await getRecent(limit: 5);
    if (recent.isNotEmpty) {
      buffer.writeln('\n【近期待办/提醒】');
      for (final r in recent.where((m) => m.category == 'summary').take(3)) {
        buffer.writeln('- $r.value');
      }
    }

    return buffer.toString();
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
  }
}

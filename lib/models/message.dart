import 'dart:convert';

/// 消息角色
enum MessageRole {
  system,
  user,
  assistant,
  tool;

  String toJson() => name;

  static MessageRole fromJson(String value) {
    return MessageRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageRole.user,
    );
  }
}

/// 消息状态
enum MessageStatus {
  sending,
  streaming,
  completed,
  error,
}

/// 单条消息
class Message {
  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final MessageStatus status;
  final DateTime createdAt;
  final List<ToolCallInfo>? toolCalls;
  final Map<String, dynamic>? metadata;
  final String? errorMessage;

  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.status = MessageStatus.completed,
    required this.createdAt,
    this.toolCalls,
    this.metadata,
    this.errorMessage,
  });

  Message copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    String? content,
    MessageStatus? status,
    DateTime? createdAt,
    List<ToolCallInfo>? toolCalls,
    Map<String, dynamic>? metadata,
    String? errorMessage,
    bool clearToolCalls = false,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      toolCalls: clearToolCalls ? null : (toolCalls ?? this.toolCalls),
      metadata: clearToolCalls ? null : (metadata ?? this.metadata),
      errorMessage: clearToolCalls ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'conversationId': conversationId,
        'role': role.toJson(),
        'content': content,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'toolCalls': toolCalls?.map((t) => t.toMap()).toList(),
        'metadata': metadata,
        'errorMessage': errorMessage,
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as String,
        conversationId: map['conversationId'] as String,
        role: MessageRole.fromJson(map['role'] as String),
        content: map['content'] as String,
        status: MessageStatus.values.firstWhere(
          (e) => e.name == (map['status'] as String? ?? 'completed'),
          orElse: () => MessageStatus.completed,
        ),
        createdAt: DateTime.parse(map['createdAt'] as String),
        toolCalls: (map['toolCalls'] as List<dynamic>?)
            ?.map((e) => ToolCallInfo.fromMap(e as Map<String, dynamic>))
            .toList(),
        metadata: map['metadata'] as Map<String, dynamic>?,
        errorMessage: map['errorMessage'] as String?,
      );

  /// 转为LLM API格式的map
  Map<String, dynamic> toLlmMessage() => {
        'role': role.toJson(),
        'content': content,
        if (toolCalls != null && toolCalls!.isNotEmpty)
          'tool_calls': toolCalls!.map((t) => t.toLlmFormat()).toList(),
      };
}

/// 对话
class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Message> messages;
  final String? modelName;
  final Map<String, dynamic>? config;

  const Conversation({
    required this.id,
    this.title = '新对话',
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.modelName,
    this.config,
  });

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Message>? messages,
    String? modelName,
    Map<String, dynamic>? config,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      modelName: modelName ?? this.modelName,
      config: config ?? this.config,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'modelName': modelName,
        'config': config,
      };

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
        id: map['id'] as String,
        title: (map['title'] as String?) ?? '新对话',
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        modelName: map['modelName'] as String?,
        config: map['config'] as Map<String, dynamic>?,
      );
}

/// 工具调用信息
class ToolCallInfo {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final String? result;
  final ToolCallStatus status;

  const ToolCallInfo({
    required this.id,
    required this.name,
    required this.arguments,
    this.result,
    this.status = ToolCallStatus.pending,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'arguments': arguments,
        'result': result,
        'status': status.name,
      };

  factory ToolCallInfo.fromMap(Map<String, dynamic> map) => ToolCallInfo(
        id: map['id'] as String,
        name: map['name'] as String,
        arguments: Map<String, dynamic>.from(map['arguments'] as Map),
        result: map['result'] as String?,
        status: ToolCallStatus.values.firstWhere(
          (e) => e.name == (map['status'] as String? ?? 'pending'),
        ),
      );

  /// LLM格式
  Map<String, dynamic> toLlmFormat() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': name,
          'arguments': jsonEncode(arguments),
        },
      };
}

enum ToolCallStatus {
  pending,
  running,
  completed,
  error,
}

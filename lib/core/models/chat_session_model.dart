import 'chat_message_model.dart';

/// Model for AI chat sessions
class ChatSession {
  final String id;
  final String userId;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final List<ChatMessage> messages;
  final bool isActive;

  ChatSession({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    DateTime? lastMessageAt,
    this.messages = const [],
    this.isActive = true,
  }) : lastMessageAt = lastMessageAt ?? createdAt;

  ChatSession copyWith({
    String? id,
    String? userId,
    String? title,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    List<ChatMessage>? messages,
    bool? isActive,
  }) {
    return ChatSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Generate a title from the first user message
  String get displayTitle {
    if (title.isNotEmpty && title != 'New Chat') {
      return title;
    }
    // Try to get title from first user message
    final firstUserMessage = messages.firstWhere(
      (m) => m.isUser,
      orElse: () => ChatMessage(
        id: '',
        content: 'New Chat',
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    // Truncate to first 50 chars
    final content = firstUserMessage.content;
    if (content.length > 50) {
      return '${content.substring(0, 47)}...';
    }
    return content.isEmpty ? 'New Chat' : content;
  }

  /// Get last message preview
  String get lastMessagePreview {
    if (messages.isEmpty) {
      return 'No messages';
    }
    final lastMessage = messages.last;
    final prefix = lastMessage.isUser ? 'You: ' : 'AI: ';
    final content = lastMessage.content;
    if (content.length > 60) {
      return '$prefix${content.substring(0, 57)}...';
    }
    return '$prefix$content';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'messages': messages.map((m) => m.toJson()).toList(),
      'isActive': isActive,
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? 'New Chat',
      createdAt: DateTime.parse(json['createdAt']),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.parse(json['lastMessageAt'])
          : null,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['isActive'] ?? true,
    );
  }

  /// Create a new empty session
  factory ChatSession.create({
    required String userId,
    String? title,
  }) {
    return ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: title ?? 'New Chat',
      createdAt: DateTime.now(),
      messages: [],
      isActive: true,
    );
  }
}

/// Model for AI chat messages
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageStatus status;
  final String? error;
  final MessageType type; // text or voice
  final String? voiceFilePath; // Path to recorded voice file
  final int? voiceDurationMs; // Duration of voice message in milliseconds
  final String? transcription; // Transcribed text from voice

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.error,
    this.type = MessageType.text,
    this.voiceFilePath,
    this.voiceDurationMs,
    this.transcription,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    MessageStatus? status,
    String? error,
    MessageType? type,
    String? voiceFilePath,
    int? voiceDurationMs,
    String? transcription,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      error: error ?? this.error,
      type: type ?? this.type,
      voiceFilePath: voiceFilePath ?? this.voiceFilePath,
      voiceDurationMs: voiceDurationMs ?? this.voiceDurationMs,
      transcription: transcription ?? this.transcription,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString(),
      'error': error,
      'type': type.toString(),
      'voiceFilePath': voiceFilePath,
      'voiceDurationMs': voiceDurationMs,
      'transcription': transcription,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      error: json['error'],
      type: json['type'] != null
          ? MessageType.values.firstWhere(
              (e) => e.toString() == json['type'],
              orElse: () => MessageType.text,
            )
          : MessageType.text,
      voiceFilePath: json['voiceFilePath'],
      voiceDurationMs: json['voiceDurationMs'],
      transcription: json['transcription'],
    );
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  error,
}

enum MessageType {
  text,
  voice,
}

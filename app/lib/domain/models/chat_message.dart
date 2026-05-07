enum ChatRole { user, assistant }

/// 챗봇 메시지
/// REST: GET /chat/history, POST /chat (응답 reply)
class ChatMessage {
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: _parseRole(json['role'] as String?),
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'role': role == ChatRole.user ? 'user' : 'assistant',
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  static ChatRole _parseRole(String? raw) {
    if (raw == 'user') return ChatRole.user;
    return ChatRole.assistant;
  }
}

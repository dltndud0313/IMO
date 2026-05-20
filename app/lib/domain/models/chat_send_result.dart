/// 챗봇 메시지 전송 결과
/// REST: POST /chat 응답 data
class ChatSendResult {
  final String reply;
  final String model; // "gemini-2.5-flash" | "guardrail" | ...
  final ChatTokenUsage? tokensUsed;
  final List<ChatSourceRef> sources;

  const ChatSendResult({
    required this.reply,
    required this.model,
    this.tokensUsed,
    this.sources = const [],
  });

  factory ChatSendResult.fromJson(Map<String, dynamic> json) => ChatSendResult(
        reply: json['reply'] as String? ?? '',
        model: json['model'] as String? ?? 'unknown',
        tokensUsed: json['tokensUsed'] is Map<String, dynamic>
            ? ChatTokenUsage.fromJson(
                json['tokensUsed'] as Map<String, dynamic>,
              )
            : null,
        sources: (json['sources'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(ChatSourceRef.fromJson)
                .toList() ??
            const [],
      );
}

class ChatTokenUsage {
  final int input;
  final int output;
  final int cached;

  const ChatTokenUsage({
    required this.input,
    required this.output,
    required this.cached,
  });

  factory ChatTokenUsage.fromJson(Map<String, dynamic> json) => ChatTokenUsage(
        input: (json['input'] as num?)?.toInt() ?? 0,
        output: (json['output'] as num?)?.toInt() ?? 0,
        cached: (json['cached'] as num?)?.toInt() ?? 0,
      );
}

class ChatSourceRef {
  final String title;
  final String file;
  final int page;
  final double score;

  const ChatSourceRef({
    required this.title,
    required this.file,
    required this.page,
    required this.score,
  });

  factory ChatSourceRef.fromJson(Map<String, dynamic> json) => ChatSourceRef(
        title: json['title'] as String? ?? '',
        file: json['file'] as String? ?? '',
        page: (json['page'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}

/// 챗봇 메시지 전송 결과
/// REST: POST /chat 응답 data
class ChatSendResult {
  final String reply;
  final String model; // "gemini-2.5-flash" | "guardrail" | ...
  final ChatTokenUsage? tokensUsed;

  const ChatSendResult({
    required this.reply,
    required this.model,
    this.tokensUsed,
  });

  factory ChatSendResult.fromJson(Map<String, dynamic> json) => ChatSendResult(
        reply: json['reply'] as String? ?? '',
        model: json['model'] as String? ?? 'unknown',
        tokensUsed: json['tokensUsed'] is Map<String, dynamic>
            ? ChatTokenUsage.fromJson(
                json['tokensUsed'] as Map<String, dynamic>,
              )
            : null,
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

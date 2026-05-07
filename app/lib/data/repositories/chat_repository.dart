import '../../domain/models/chat_message.dart';
import '../services/api_service.dart';

/// 챗봇 대화 Repository
/// 데이터 출처: 서버 API (`POST/GET/DELETE /chat`)
class ChatRepository {
  final ApiService _api;

  ChatRepository(this._api);

  Future<List<ChatMessage>> loadHistory() => _api.getChatHistory();

  /// 메시지 전송 후 어시스턴트 응답을 ChatMessage로 변환해 반환
  Future<ChatMessage> send(String message) async {
    final result = await _api.sendChatMessage(message);
    return ChatMessage(
      role: ChatRole.assistant,
      content: result.reply,
      timestamp: DateTime.now(),
    );
  }

  Future<void> clear() => _api.clearChatHistory();
}

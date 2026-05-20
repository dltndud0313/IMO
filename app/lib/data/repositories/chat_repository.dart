import 'package:flutter/foundation.dart';

import '../../domain/models/chat_message.dart';
import '../services/api_service.dart';

class ChatRepository {
  final ApiService _api;

  ChatRepository(this._api);

  Future<List<ChatMessage>> loadHistory() => _api.getChatHistory();

  Future<ChatMessage> send(String message) async {
    final result = await _api.sendChatMessage(message);
    if (kDebugMode) {
      debugPrint(
        '[ChatRepository] model=${result.model} '
        'sources=${result.sources.map((source) => '${source.file}:${source.page}').join(', ')}',
      );
    }
    return ChatMessage(
      role: ChatRole.assistant,
      content: result.reply,
      timestamp: DateTime.now(),
    );
  }

  Future<void> clear() => _api.clearChatHistory();
}

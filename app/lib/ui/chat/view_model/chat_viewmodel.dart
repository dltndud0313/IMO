import 'package:flutter/foundation.dart';

import '../../../data/repositories/chat_repository.dart';
import '../../../domain/models/chat_message.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel(this._repo);

  final ChatRepository _repo;

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isClearing = false;
  bool get isClearing => _isClearing;

  /// SnackBar 1회 노출 후 호출 — 중복 노출 방지
  void consumeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadHistory() async {
    if (_isInitializing) return;
    _isInitializing = true;
    notifyListeners();

    try {
      _messages = await _repo.loadHistory();
    } catch (e) {
      _errorMessage = _stripException(e);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    _messages = [
      ..._messages,
      ChatMessage(
        role: ChatRole.user,
        content: trimmed,
        timestamp: DateTime.now(),
      ),
    ];
    _isSending = true;
    notifyListeners();

    try {
      final reply = await _repo.send(trimmed);
      _messages = [..._messages, reply];
    } catch (e) {
      _errorMessage = _stripException(e);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    if (_isClearing) return;
    _isClearing = true;
    notifyListeners();

    try {
      await _repo.clear();
      _messages = [];
    } catch (e) {
      _errorMessage = _stripException(e);
    } finally {
      _isClearing = false;
      notifyListeners();
    }
  }

  String _stripException(Object e) {
    final raw = e.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }
}

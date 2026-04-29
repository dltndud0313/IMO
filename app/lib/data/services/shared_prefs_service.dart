import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전반의 설정 및 인증 토큰 저장 관리
class SharedPrefsService {
  final SharedPreferences _prefs;

  SharedPrefsService(this._prefs);

  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserId = 'user_id';
  static const _keyTtsEnabled = 'tts_enabled';

  // ─── Auth Tokens ───

  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await _prefs.setString(_keyAccessToken, accessToken);
    await _prefs.setString(_keyRefreshToken, refreshToken);
    // 빈 값이 아니면 저장
    if (userId.isNotEmpty) {
      await _prefs.setString(_keyUserId, userId);
    }
  }

  Future<void> clearAuthTokens() async {
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyUserId);
  }

  String? getAccessToken() => _prefs.getString(_keyAccessToken);
  String? getRefreshToken() => _prefs.getString(_keyRefreshToken);
  String? getUserId() => _prefs.getString(_keyUserId);

  // ─── Settings ───

  Future<void> setTtsEnabled(bool enabled) async {
    await _prefs.setBool(_keyTtsEnabled, enabled);
  }

  bool getTtsEnabled() {
    return _prefs.getBool(_keyTtsEnabled) ?? true;
  }
}

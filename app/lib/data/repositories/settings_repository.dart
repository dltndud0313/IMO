import '../services/api_service.dart';
import '../services/shared_prefs_service.dart';

/// 앱 환경설정 (웨어러블/알림) 동기화
class SettingsRepository {
  final ApiService _api;
  final SharedPrefsService _prefs;

  SettingsRepository(this._api, this._prefs);

  Future<Map<String, dynamic>> getSettings() async {
    return await _api.getSettings();
  }

  Future<void> updateTtsEnabled(bool enabled) async {
    // 1. 서버 동기화
    await _api.updateSettings({'ttsEnabled': enabled});
    // 2. 로컬 반영
    await _prefs.setTtsEnabled(enabled);
  }

  bool isTtsEnabledGlobally() {
    return _prefs.getTtsEnabled();
  }

  Future<void> updatePiConnectionInfo(String ip, int port) async {
    await _api.updateSettings({
      'wearable': {
        'raspberryPiIp': ip,
        'raspberryPiPort': port,
      }
    });
    // 향후 소켓 서비스 재시작 등 트리거
  }

  Future<void> deleteAllData(String confirmText) async {
    await _api.deleteUserData(confirmText);
  }
}

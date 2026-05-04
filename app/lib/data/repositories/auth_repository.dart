import 'dart:async';

import '../services/auth_service.dart';
import '../services/shared_prefs_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// 인증 상태 및 토큰 관리 Repository
class AuthRepository {
  final AuthService _authService;
  final SharedPrefsService _prefsService;

  final _statusCtrl = StreamController<AuthStatus>.broadcast();
  AuthStatus _currentStatus = AuthStatus.unknown;

  AuthRepository(this._authService, this._prefsService);

  Stream<AuthStatus> get status => _statusCtrl.stream;
  AuthStatus get currentStatus => _currentStatus;

  /// 초기화 시 로컬 저장소에서 토큰 확인
  Future<void> init() async {
    final token = _prefsService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _updateStatus(AuthStatus.authenticated);
    } else {
      _updateStatus(AuthStatus.unauthenticated);
    }
  }

  /// 로그인
  Future<void> login(String email, String password) async {
    final tokens = await _authService.login(email: email, password: password);
    await _saveTokens(tokens);
    _updateStatus(AuthStatus.authenticated);
  }

  /// 회원가입
  Future<void> signUp(String email, String password, String nickname) async {
    final tokens = await _authService.signUp(
        email: email, password: password, nickname: nickname);
    await _saveTokens(tokens);
    _updateStatus(AuthStatus.authenticated);
  }

  /// 로그아웃
  Future<void> logout() async {
    await _prefsService.clearAuthTokens();
    _updateStatus(AuthStatus.unauthenticated);
  }

  /// 토큰 갱신
  /// (Dio 인터셉터 등에서 401 발생 시 호출됨)
  Future<String?> refreshToken() async {
    final refreshToken = _prefsService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await logout();
      return null;
    }
    try {
      final newTokens = await _authService.refresh(refreshToken);
      await _saveTokens(newTokens);
      return newTokens.accessToken;
    } catch (_) {
      await logout();
      return null;
    }
  }

  Future<void> _saveTokens(AuthTokens tokens) async {
    await _prefsService.saveAuthTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      userId: tokens.userId,
    );
  }

  void _updateStatus(AuthStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusCtrl.add(status);
    }
  }

  void dispose() {
    _statusCtrl.close();
  }
}

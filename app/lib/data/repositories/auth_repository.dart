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
  Future<bool> checkEmailAvailable(String email) async {
    return _authService.checkEmail(email);
  }

  Future<void> logout() async {
    await _prefsService.clearAuthTokens();
    _updateStatus(AuthStatus.unauthenticated);
  }

  /// 토큰 갱신
  /// (Dio 인터셉터 등에서 401 발생 시 호출됨)
  ///
  /// 실패 분기:
  /// - refresh token 없음 → 로그아웃 (사용자 의도)
  /// - 401/403 (refresh token 진짜 무효) → 로그아웃
  /// - 네트워크 끊김/타임아웃/5xx → 토큰 유지, null 반환
  ///   (호출부는 사용자에게 재시도/오프라인 안내만 하고 세션은 보존)
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
    } on AuthRefreshException catch (error) {
      if (error.kind == AuthRefreshFailureKind.unauthorized) {
        await logout();
      }
      // network/server 일시 장애는 토큰을 보존해 다음 시도에서 회복 가능하게 한다.
      return null;
    } catch (_) {
      // 분류되지 않은 예외는 안전한 쪽(토큰 유지)으로 처리.
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

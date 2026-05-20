import 'package:dio/dio.dart';

/// refresh() 실패 사유 — 호출부가 401/403(진짜 무효) 과 네트워크/서버 일시 장애를
/// 구분해서 토큰을 지울지 유지할지 결정할 수 있게 한다.
enum AuthRefreshFailureKind { unauthorized, network, server, unknown }

class AuthRefreshException implements Exception {
  AuthRefreshException({
    required this.message,
    required this.kind,
    this.statusCode,
  });

  final String message;
  final AuthRefreshFailureKind kind;
  final int? statusCode;

  @override
  String toString() =>
      'AuthRefreshException($kind, status=$statusCode): $message';
}

/// 인증 정보 데이터 클래스 (Token 등)
class AuthTokens {
  final String userId;
  final String accessToken;
  final String refreshToken;

  const AuthTokens({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        userId: (json['userId'] ?? '').toString(),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
}

/// 인증 API 클라이언트 (API-01, API-02, API-03)
/// 이 서비스 자체는 토큰 인터셉터를 타지 않는 Dio 인스턴스를 사용해야 합니다.
class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  Future<bool> checkEmail(String email) async {
    try {
      final res = await _dio.get(
        '/auth/email/check',
        queryParameters: {'email': email},
      );
      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>;
        return data['available'] == true;
      }
      _throwApiError(res.data, 'Email check failed');
    } on DioException catch (error) {
      _throwApiError(error.response?.data, 'Email check failed');
    }
  }

  /// API-01: 회원가입
  Future<AuthTokens> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      final res = await _dio.post('/auth/signup', data: {
        'email': email,
        'password': password,
        'nickname': nickname,
      });
      if (res.data['success'] == true) {
        return AuthTokens.fromJson(res.data['data'] as Map<String, dynamic>);
      }
      _throwApiError(res.data, 'Sign up failed');
    } on DioException catch (error) {
      _throwApiError(error.response?.data, 'Sign up failed');
    }
  }

  /// API-02: 로그인
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      if (res.data['success'] == true) {
        return AuthTokens.fromJson(res.data['data'] as Map<String, dynamic>);
      }
      _throwApiError(res.data, 'Login failed');
    } on DioException catch (error) {
      if (error.response == null) {
        throw Exception('Network unavailable');
      }
      _throwApiError(error.response?.data, 'Login failed');
    }
  }

  /// API-03: 토큰 갱신
  /// refreshToken을 사용하여 새로운 accessToken, refreshToken을 발급받음.
  /// 실패 시 [AuthRefreshException] 을 던지며, 호출부는 `kind` 로 401/403 vs
  /// 네트워크/서버 일시 장애를 구분한다.
  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final res = await _dio.post('/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      // API 명세상 refresh 응답에는 userId가 없을 수 있으므로, 기존 userId를 유지하거나 처리 필요.
      // 여기서는 명세 그대로 처리.
      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>;
        return AuthTokens(
          userId: (data['userId'] ?? '').toString(), // 만약 없다면 Repository에서 병합 처리
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
      }
      throw AuthRefreshException(
        message:
            _readApiErrorMessage(res.data, 'Token refresh failed'),
        kind: AuthRefreshFailureKind.server,
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        throw AuthRefreshException(
          message:
              _readApiErrorMessage(error.response?.data, 'Token refresh failed'),
          kind: AuthRefreshFailureKind.unauthorized,
          statusCode: status,
        );
      }
      if (error.response == null) {
        // connect/receive timeout, no internet 등 응답 자체가 없는 경우
        throw AuthRefreshException(
          message: 'Network unavailable',
          kind: AuthRefreshFailureKind.network,
        );
      }
      throw AuthRefreshException(
        message:
            _readApiErrorMessage(error.response?.data, 'Token refresh failed'),
        kind: AuthRefreshFailureKind.server,
        statusCode: status,
      );
    }
  }

  String _readApiErrorMessage(dynamic body, String fallbackMessage) {
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
    return fallbackMessage;
  }

  Never _throwApiError(dynamic body, String fallbackMessage) {
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw Exception(message);
        }
      }
      if (error is String && error.isNotEmpty) {
        throw Exception(error);
      }
    }
    throw Exception(fallbackMessage);
  }
}

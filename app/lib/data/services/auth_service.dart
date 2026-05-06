import 'package:dio/dio.dart';

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
      _throwApiError(error.response?.data, 'Login failed');
    }
  }

  /// API-03: 토큰 갱신
  /// refreshToken을 사용하여 새로운 accessToken, refreshToken을 발급받음
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
      _throwApiError(res.data, 'Token refresh failed');
    } on DioException catch (error) {
      _throwApiError(error.response?.data, 'Token refresh failed');
    }
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

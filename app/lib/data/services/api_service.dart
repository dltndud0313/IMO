import 'package:dio/dio.dart';

import '../../domain/models/exercise_type.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/workout_session.dart';

/// Backend REST API 클라이언트
/// Base URL: https://api.imo-app.com/v1 (또는 환경변수)
/// DIO 인스턴스를 주입받아 사용 (인증 인터셉터는 외부에서 설정됨)
class ApiService {
  final Dio _dio;

  ApiService(this._dio);

  // ═══════════════════════════════════════════════════════════
  //  사용자 프로필 (API-04, API-05)
  // ═══════════════════════════════════════════════════════════

  /// API-04: 프로필 조회
  Future<UserProfile> getProfile() async {
    final res = await _dio.get('/users/me/profile');
    if (res.data['success'] == true) {
      return UserProfile.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    throw Exception(res.data['error'] ?? 'getProfile failed');
  }

  /// API-05: 프로필 수정
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final res = await _dio.put(
      '/users/me/profile',
      data: profile.toJson(),
    );
    if (res.data['success'] == true) {
      // 응답에는 updatedAt등 일부만 오므로 기존 데이터와 머지하는 로직은 Repo에서 처리하거나,
      // 서버가 전체를 내려준다고 가정. 명세상 일부만 내려주므로 성공 여부만 확인.
      return UserProfile.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    throw Exception(res.data['error'] ?? 'updateProfile failed');
  }

  // ═══════════════════════════════════════════════════════════
  //  설정 (API-13, API-14)
  // ═══════════════════════════════════════════════════════════

  /// API-13: 사용자 설정 조회
  Future<Map<String, dynamic>> getSettings() async {
    final res = await _dio.get('/users/me/settings');
    if (res.data['success'] == true) {
      return res.data['data'] as Map<String, dynamic>;
    }
    throw Exception(res.data['error'] ?? 'getSettings failed');
  }

  /// API-14: 사용자 설정 수정 (부분 업데이트 허용)
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    final res = await _dio.put(
      '/users/me/settings',
      data: settings,
    );
    if (res.data['success'] != true) {
      throw Exception(res.data['error'] ?? 'updateSettings failed');
    }
  }

  /// API-15: 데이터 초기화
  Future<void> deleteUserData(String confirmText) async {
    final res = await _dio.delete(
      '/users/me/data',
      data: {'confirmText': confirmText},
    );
    if (res.data['success'] != true) {
      throw Exception(res.data['error'] ?? 'deleteUserData failed');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  세션 (API-06, API-07, API-08, API-09)
  // ═══════════════════════════════════════════════════════════

  /// API-06: 세션 결과 저장
  Future<String> saveSession(WorkoutSession session) async {
    final res = await _dio.post(
      '/sessions',
      data: session.toJson(),
    );
    if (res.data['success'] == true) {
      return res.data['data']['sessionId'] as String;
    }
    throw Exception(res.data['error'] ?? 'saveSession failed');
  }

  /// API-07: 세션 목록 조회 (날짜별 / 월별)
  Future<Map<String, dynamic>> getSessions({
    String? date,
    String? month,
    String? exerciseType,
    int page = 1,
    int size = 20,
  }) async {
    final query = {
      if (date != null) 'date': date,
      if (month != null) 'month': month,
      if (exerciseType != null) 'exerciseType': exerciseType,
      'page': page,
      'size': size,
    };
    final res = await _dio.get('/sessions', queryParameters: query);
    if (res.data['success'] == true) {
      return res.data['data'] as Map<String, dynamic>;
    }
    throw Exception(res.data['error'] ?? 'getSessions failed');
  }

  /// API-08: 세션 상세 조회
  Future<WorkoutSession> getSessionDetail(String sessionId) async {
    final res = await _dio.get('/sessions/$sessionId');
    if (res.data['success'] == true) {
      return WorkoutSession.fromJson(res.data['data'] as Map<String, dynamic>);
    }
    throw Exception(res.data['error'] ?? 'getSessionDetail failed');
  }

  /// API-09: 세션 삭제
  Future<void> deleteSession(String sessionId) async {
    final res = await _dio.delete('/sessions/$sessionId');
    if (res.data['success'] != true) {
      throw Exception(res.data['error'] ?? 'deleteSession failed');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  통계 (API-10, API-11, API-12)
  // ═══════════════════════════════════════════════════════════

  /// API-10: 주간 통계 조회
  Future<Map<String, dynamic>> getWeeklyStats(
      String weekStart, {String? exerciseType}) async {
    final query = {
      'weekStart': weekStart,
      if (exerciseType != null) 'exerciseType': exerciseType,
    };
    final res = await _dio.get('/statistics/weekly', queryParameters: query);
    if (res.data['success'] == true) {
      return res.data['data'] as Map<String, dynamic>;
    }
    throw Exception(res.data['error'] ?? 'getWeeklyStats failed');
  }

  /// API-11: 주간 히트맵 데이터
  Future<Map<String, dynamic>> getWeeklyHeatmap(
      String weekStart, {String? exerciseType}) async {
    final query = {
      'weekStart': weekStart,
      if (exerciseType != null) 'exerciseType': exerciseType,
    };
    final res = await _dio.get('/statistics/weekly/heatmap', queryParameters: query);
    if (res.data['success'] == true) {
      return res.data['data'] as Map<String, dynamic>;
    }
    throw Exception(res.data['error'] ?? 'getWeeklyHeatmap failed');
  }

  /// API-12: 주간 밸런스 데이터
  Future<Map<String, dynamic>> getWeeklyBalance(
      String weekStart, {String? exerciseType}) async {
    final query = {
      'weekStart': weekStart,
      if (exerciseType != null) 'exerciseType': exerciseType,
    };
    final res = await _dio.get('/statistics/weekly/balance', queryParameters: query);
    if (res.data['success'] == true) {
      return res.data['data'] as Map<String, dynamic>;
    }
    throw Exception(res.data['error'] ?? 'getWeeklyBalance failed');
  }

  // ═══════════════════════════════════════════════════════════
  //  운동 정보 (API-16)
  // ═══════════════════════════════════════════════════════════

  /// API-16: 운동 종목 목록 조회
  Future<List<ExerciseInfo>> getExercises() async {
    final res = await _dio.get('/exercises');
    if (res.data['success'] == true) {
      final list = res.data['data']['exercises'] as List;
      return list.map((e) => ExerciseInfo.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception(res.data['error'] ?? 'getExercises failed');
  }
}

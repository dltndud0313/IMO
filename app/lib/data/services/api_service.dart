// ignore_for_file: use_null_aware_elements

import 'package:dio/dio.dart';

import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_send_result.dart';
import '../../domain/models/exercise_type.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/workout_session.dart';

const _prodBackendApiBaseUrl = 'https://k14c203.p.ssafy.io/api/v1';

/// 예: `--dart-define=BACKEND_API_BASE_URL=http://10.0.2.2:8000/api/v1`
/// 으로 실행하면 디버그/실기기 환경에서 원하는 백엔드로 쉽게 붙일 수 있다.
const backendApiBaseUrl = String.fromEnvironment(
  'BACKEND_API_BASE_URL',
  defaultValue: _prodBackendApiBaseUrl,
);

const isUsingCustomBackendApi = backendApiBaseUrl != _prodBackendApiBaseUrl;

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
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.put(
        '/users/me/password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      if (res.data['success'] != true) {
        throw Exception(_apiErrorMessage(res.data, 'changePassword failed'));
      }
    } on DioException catch (error) {
      throw Exception(
        _apiErrorMessage(error.response?.data, 'changePassword failed'),
      );
    }
  }

  String _apiErrorMessage(dynamic body, String fallbackMessage) {
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        return error['message']?.toString() ?? fallbackMessage;
      }
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
    return fallbackMessage;
  }

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
      final data = res.data['data'] as Map<String, dynamic>;
      return WorkoutSession.fromJson(_normalizeSessionDetail(data));
    }
    throw Exception(res.data['error'] ?? 'getSessionDetail failed');
  }

  Map<String, dynamic> _normalizeSessionDetail(Map<String, dynamic> data) {
    if (data.containsKey('session_id')) {
      return data;
    }

    final start = DateTime.parse(data['startTime'] as String);
    final end = DateTime.parse(data['endTime'] as String);
    final sets = (data['sets'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final summary = data['overallSummary'] as Map<String, dynamic>? ?? const {};
    final balance = data['muscleBalance'] as Map<String, dynamic>?;
    final muscleMap = data['muscleMap'] as Map<String, dynamic>?;
    // 백엔드 B-1: GET 응답에 추가된 round-trip 무손실용 raw 블록 (camelCase).
    final calibration = data['calibrationSummary'] as Map<String, dynamic>?;
    final balanceSummary = data['balanceSummary'] as Map<String, dynamic>?;
    final targetReps = sets
        .map((set) => (set['targetReps'] as num?)?.toInt() ?? 0)
        .toList();
    final actualReps = sets
        .map((set) => (set['actualReps'] as num?)?.toInt() ?? 0)
        .toList();
    final totalReps = (summary['totalReps'] as num?)?.toInt() ??
        actualReps.fold<int>(0, (sum, reps) => sum + reps);
    final totalDuration = (data['totalDurationSeconds'] as num?)?.toInt() ??
        end.difference(start).inSeconds.clamp(0, 1 << 31);

    return {
      'session_id': data['sessionId'],
      'exercise_type': data['exerciseType'],
      'status': 'completed',
      'end_reason': 'unknown',
      'started_at': start.toIso8601String(),
      'ended_at': end.toIso8601String(),
      'duration_sec': totalDuration,
      'set_count': sets.length,
      'target_reps_per_set': targetReps,
      'actual_reps_per_set': actualReps,
      'rest_sec': sets.isNotEmpty
          ? ((sets.first['restDurationSeconds'] as num?)?.toInt() ?? 0)
          : 0,
      'total_reps': totalReps,
      'valid_reps': totalReps,
      'avg_target_muscle': _numToDouble(summary['avgTargetActivation']),
      'avg_assist_muscle': 0,
      'avg_compensator': 0,
      'compensation_count':
          (summary['totalCompensationCount'] as num?)?.toInt() ?? 0,
      'fatigue_onset_set': (summary['fatigueOnsetSet'] as num?)?.toInt(),
      'fatigue_onset_rep': (summary['fatigueOnsetRep'] as num?)?.toInt(),
      if (muscleMap != null && muscleMap.isNotEmpty)
        // 스케일 계약: 백엔드 응답은 이미 0~100 percent → 변환 없이 그대로.
        'muscle_map': muscleMap,
      if (calibration != null)
        'calibration_summary': {
          'ch1_mvc': (calibration['ch1Mvc'] as num?)?.toDouble() ?? 0.0,
          'ch2_mvc': (calibration['ch2Mvc'] as num?)?.toDouble() ?? 0.0,
          'ch3_mvc': (calibration['ch3Mvc'] as num?)?.toDouble() ?? 0.0,
          'ch4_mvc': (calibration['ch4Mvc'] as num?)?.toDouble() ?? 0.0,
        },
      // raw balanceSummary 블록이 있으면 우선 사용(무손실), 없으면 구버전
      // 세션 호환을 위해 파생 muscleBalance에서 역산한다.
      if (balanceSummary != null)
        // 스케일 계약: 백엔드 응답은 이미 0~100 percent → 변환 없이 그대로.
        'balance_summary': {
          'enabled': balanceSummary['enabled'] as bool? ?? true,
          'reason': balanceSummary['reason']?.toString() ?? 'backend_detail',
          'left_value': _numToDoubleOrNull(balanceSummary['leftValue']),
          'right_value': _numToDoubleOrNull(balanceSummary['rightValue']),
          'diff_value': _numToDoubleOrNull(balanceSummary['diffValue']),
          'balance_label': balanceSummary['balanceLabel']?.toString(),
        }
      else if (balance != null)
        'balance_summary': {
          'enabled': true,
          'reason': balance['status']?.toString() ?? 'backend_detail',
          'left_value': _numToDoubleOrNull(balance['leftAvg']),
          'right_value': _numToDoubleOrNull(balance['rightAvg']),
          'diff_value': _numToDoubleOrNull(balance['balanceRatio']),
          'balance_label': balance['status']?.toString(),
        },
      'set_results': sets.map((set) {
        return {
          'set_index': (set['setNumber'] as num?)?.toInt() ?? 0,
          'target_reps': (set['targetReps'] as num?)?.toInt() ?? 0,
          'actual_reps': (set['actualReps'] as num?)?.toInt() ?? 0,
          'compensation_count':
              (set['compensationCount'] as num?)?.toInt() ?? 0,
          'avg_speed': set['avgSpeed']?.toString().toLowerCase() ?? 'normal',
          'started_at': start.toIso8601String(),
          'ended_at': end.toIso8601String(),
        };
      }).toList(),
    };
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

  // ═══════════════════════════════════════════════════════════
  //  챗봇 (API-CHAT)
  // ═══════════════════════════════════════════════════════════

  /// 챗봇 메시지 전송
  Future<ChatSendResult> sendChatMessage(String message) async {
    try {
      final res = await _dio.post(
        '/chat',
        data: {'message': message},
      );
      if (res.data['success'] == true) {
        return ChatSendResult.fromJson(res.data['data'] as Map<String, dynamic>);
      }
      throw Exception(_apiErrorMessage(res.data, 'sendChatMessage failed'));
    } on DioException catch (error) {
      throw Exception(
        _apiErrorMessage(error.response?.data, 'sendChatMessage failed'),
      );
    }
  }

  /// 챗봇 대화 히스토리 조회
  Future<List<ChatMessage>> getChatHistory() async {
    try {
      final res = await _dio.get('/chat/history');
      if (res.data['success'] == true) {
        final messages = (res.data['data']?['messages'] as List?) ?? const [];
        return messages
            .whereType<Map<String, dynamic>>()
            .map(ChatMessage.fromJson)
            .toList();
      }
      throw Exception(_apiErrorMessage(res.data, 'getChatHistory failed'));
    } on DioException catch (error) {
      throw Exception(
        _apiErrorMessage(error.response?.data, 'getChatHistory failed'),
      );
    }
  }

  /// 챗봇 대화 초기화
  Future<void> clearChatHistory() async {
    try {
      final res = await _dio.delete('/chat');
      if (res.data['success'] != true) {
        throw Exception(_apiErrorMessage(res.data, 'clearChatHistory failed'));
      }
    } on DioException catch (error) {
      throw Exception(
        _apiErrorMessage(error.response?.data, 'clearChatHistory failed'),
      );
    }
  }
}

/// 스케일 계약(2026-05-18 통일): 활성도 값은 Pi·앱·백엔드·DB·GET 응답 전 구간
/// 0~100 percent. GET 응답 값은 이미 percent 이므로 변환 없이 모델에 싣는다.
double _numToDouble(Object? value) =>
    value is num ? value.toDouble() : 0.0;

double? _numToDoubleOrNull(Object? value) =>
    value is num ? value.toDouble() : null;

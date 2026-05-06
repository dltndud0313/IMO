import '../../domain/models/workout_session.dart';
import '../services/api_service.dart';

/// 세션 기록 CRUD (서버와 동기화)
class SessionHistoryRepository {
  final ApiService _api;

  SessionHistoryRepository(this._api);

  /// 운동 종료 시 기록 저장 
  Future<String> saveSession(WorkoutSession session) async {
    // 1. Local 캐시로 저장 시도 (선택)
    
    // 2. 서버로 저장
    try {
      final id = await _api.saveSession(session);
      return id;
    } catch (e) {
      // 서버 전송 실패 시 로컬에 저장해두고 스케줄러로 동기화 재시도하도록 구성 가능
      rethrow;
    }
  }

  /// 특정 달의 운동 기록 조회 (달력용)
  Future<List<WorkoutSession>> getSessionsByMonth(String monthYYYYMM) async {
    final data = await _api.getSessions(month: monthYYYYMM, size: 100);
    final rawList = data['sessions'] as List;
    // 간략화된 정보로 먼저 파싱. 만약 전체 모델 매핑이 필요하다면 별도 모델(SessionSummary) 사용
    // MVP에서는 모두 WorkoutSession으로 맵핑 가능하게 구성 (없는 필드는 dummy 또는 null 처리)
    return rawList.map((j) => _parseSummary(j as Map<String, dynamic>)).toList();
  }

  /// 날짜별 기록 조회
  Future<List<WorkoutSession>> getSessionsByDate(String dateYYYYMMDD) async {
    final data = await _api.getSessions(date: dateYYYYMMDD, size: 50);
    final rawList = data['sessions'] as List;
    final filtered = rawList.where((j) {
      final session = j as Map<String, dynamic>;
      final date = session['date']?.toString();
      final startTime = session['startTime']?.toString();
      return date == dateYYYYMMDD ||
          (startTime != null && startTime.startsWith(dateYYYYMMDD));
    });
    return filtered
        .map((j) => _parseSummary(j as Map<String, dynamic>))
        .toList();
  }

  /// 세션 상세 조회 (repDetails, graphs 포함)
  Future<WorkoutSession> getSessionDetail(String sessionId) async {
    return await _api.getSessionDetail(sessionId);
  }

  /// 세션 삭제
  Future<void> deleteSession(String sessionId) async {
    await _api.deleteSession(sessionId);
  }

  /// 주간 통계/열화상(Heatmap) 등의 데이터는 ViewModel에서 직접 ApiService를
  /// 호출하거나, 전용 StatsRepository를 만들어서 위임합니다.
  
  WorkoutSession _parseSummary(Map<String, dynamic> json) {
    final start = DateTime.parse(json['startTime'] as String);
    final end = DateTime.parse(json['endTime'] as String);
    final durationSec = end.difference(start).inSeconds.clamp(0, 1 << 31);
    final totalSets = json['totalSets'] as int? ?? 0;
    final totalReps = json['totalReps'] as int? ?? 0;

    // getSessions API 응답에는 간략화된 정보만 들어있음.
    // 임시로 필요한 값만 채워 넣기
    return WorkoutSession.fromJson({
      'session_id': json['sessionId'],
      'exercise_type': json['exerciseType'],
      'status': 'completed',
      'end_reason': 'unknown',
      'started_at': start.toIso8601String(),
      'ended_at': end.toIso8601String(),
      'duration_sec': durationSec,
      'set_count': totalSets,
      'target_reps_per_set': <int>[],
      'actual_reps_per_set': totalSets > 0
          ? List<int>.filled(totalSets, totalReps ~/ totalSets)
          : <int>[],
      'rest_sec': 0,
      'total_reps': totalReps,
      'valid_reps': totalReps,
      'avg_target_muscle': (json['avgTargetActivation'] as num?)?.toDouble() ?? 0,
      'avg_assist_muscle': 0,
      'avg_compensator': 0,
      'compensation_count': 0,
      'set_results': [],
      'totalDurationSeconds': 0, // 없는 값은 더미
      'sets': [], // 
      'overallSummary': {
        'totalReps': json['totalReps'] ?? 0,
        'totalTargetReps': 0,
        'completionRate': json['completionRate'] ?? 0,
        'avgTargetActivation': json['avgTargetActivation'] ?? 0,
        'totalCompensationCount': 0,
        'avgStabilityScore': 0,
      }
    }); 
  }
}

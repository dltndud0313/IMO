import 'realtime_feedback.dart';

/// 세트 단위 결과
/// 백엔드 DB의 `workout_set_results` 테이블 구조에 대응
class SetResult {
  final int setIndex;
  final int targetReps;
  final int actualReps;
  final int compensationCount;
  final String avgSpeed; // normal, fast, slow
  final DateTime startedAt;
  final DateTime endedAt;

  const SetResult({
    required this.setIndex,
    required this.targetReps,
    required this.actualReps,
    required this.compensationCount,
    required this.avgSpeed,
    required this.startedAt,
    required this.endedAt,
  });

  factory SetResult.fromJson(Map<String, dynamic> json) => SetResult(
        setIndex: json['set_index'] as int,
        targetReps: json['target_reps'] as int,
        actualReps: json['actual_reps'] as int,
        compensationCount: json['compensation_count'] as int,
        avgSpeed: json['avg_speed'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: DateTime.parse(json['ended_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'set_index': setIndex,
        'target_reps': targetReps,
        'actual_reps': actualReps,
        'compensation_count': compensationCount,
        'avg_speed': avgSpeed,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
      };
}

/// SET_COMPLETED 이벤트 (WS-16) — 진행 중 실시간으로 Pi에서 수신하는 이벤트용
class SetCompletedEvent {
  final SetResult result;
  final int totalSets;
  final int restDurationSeconds;
  final int? nextSetNumber; // 마지막 세트면 null

  const SetCompletedEvent({
    required this.result,
    required this.totalSets,
    required this.restDurationSeconds,
    this.nextSetNumber,
  });

  factory SetCompletedEvent.fromJson(Map<String, dynamic> json) {
    // Pi가 SET_COMPLETED를 보낼때도 이 구조로 맞췄다고 가정하거나,
    // WS 파싱용 별도 매핑이 필요함 (여기서는 백엔드용 모델인 SetResult 재사용)
    return SetCompletedEvent(
      result: SetResult(
        setIndex: json['completedSet'] as int,
        targetReps: json['targetReps'] as int,
        actualReps: json['actualReps'] as int,
        compensationCount: (json['setSummary'] as Map)['compensationCount'] as int,
        avgSpeed: (json['setSummary'] as Map)['avgSpeedStatus']?.toString().toLowerCase() ?? 'normal',
        startedAt: DateTime.now().subtract(Duration(seconds: json['setDurationSeconds'] as int)), // 대략적 계산
        endedAt: DateTime.now(), // 또는 timestamp 사용
      ),
      totalSets: json['totalSets'] as int,
      restDurationSeconds: json['restDurationSeconds'] as int,
      nextSetNumber: json['nextSetNumber'] as int?,
    );
  }
}

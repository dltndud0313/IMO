import 'exercise_type.dart';
import 'set_result.dart';

/// 캘리브레이션 기준값 요약 (백엔드 저장용)
class CalibrationSummary {
  final double ch1Mvc;
  final double ch2Mvc;
  final double ch3Mvc;

  const CalibrationSummary({
    required this.ch1Mvc,
    required this.ch2Mvc,
    required this.ch3Mvc,
  });

  factory CalibrationSummary.fromJson(Map<String, dynamic> json) => CalibrationSummary(
        ch1Mvc: (json['ch1_mvc'] as num).toDouble(),
        ch2Mvc: (json['ch2_mvc'] as num).toDouble(),
        ch3Mvc: (json['ch3_mvc'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'ch1_mvc': ch1Mvc,
        'ch2_mvc': ch2Mvc,
        'ch3_mvc': ch3Mvc,
      };
}

/// 부위별 활성도 히트맵 (백엔드 저장용)
class MuscleMap {
  final double chest;
  final double leftShoulder;
  final double rightShoulder;
  final double leftTriceps;
  final double rightTriceps;

  const MuscleMap({
    required this.chest,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftTriceps,
    required this.rightTriceps,
  });

  factory MuscleMap.fromJson(Map<String, dynamic> json) => MuscleMap(
        chest: (json['chest'] as num).toDouble(),
        leftShoulder: (json['left_shoulder'] as num).toDouble(),
        rightShoulder: (json['right_shoulder'] as num).toDouble(),
        leftTriceps: (json['left_triceps'] as num).toDouble(),
        rightTriceps: (json['right_triceps'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'chest': chest,
        'left_shoulder': leftShoulder,
        'right_shoulder': rightShoulder,
        'left_triceps': leftTriceps,
        'right_triceps': rightTriceps,
      };
}

/// 좌우 밸런스 요약값 (백엔드 저장용)
class BalanceSummary {
  final bool enabled;
  final String reason;
  final double? leftValue;
  final double? rightValue;
  final double? diffValue;
  final String? balanceLabel;

  const BalanceSummary({
    required this.enabled,
    required this.reason,
    this.leftValue,
    this.rightValue,
    this.diffValue,
    this.balanceLabel,
  });

  factory BalanceSummary.fromJson(Map<String, dynamic> json) => BalanceSummary(
        enabled: json['enabled'] as bool,
        reason: json['reason'] as String,
        leftValue: json['left_value'] != null ? (json['left_value'] as num).toDouble() : null,
        rightValue: json['right_value'] != null ? (json['right_value'] as num).toDouble() : null,
        diffValue: json['diff_value'] != null ? (json['diff_value'] as num).toDouble() : null,
        balanceLabel: json['balance_label'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'reason': reason,
        if (leftValue != null) 'left_value': leftValue,
        if (rightValue != null) 'right_value': rightValue,
        if (diffValue != null) 'diff_value': diffValue,
        if (balanceLabel != null) 'balance_label': balanceLabel,
      };
}

/// 운동 세션 전체 결과
/// 백엔드 DB 구조와 1:1 매핑됨 (workout_sessions 테이블 및 하위 테이블들)
class WorkoutSession {
  final int? userId; // 앱에서 주입
  final String sessionId;
  final ExerciseType exerciseType; // pushup 등
  final String status; // completed, stopped, emergency_stopped 등
  final String endReason; // auto_completed 등
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSec;
  final int setCount;
  final List<int> targetRepsPerSet;
  final List<int> actualRepsPerSet;
  final int restSec;
  final int totalReps;
  final int validReps;
  final double avgTargetMuscle;
  final double avgAssistMuscle;
  final double avgCompensator;
  final int compensationCount;
  final int? fatigueOnsetSet;
  final int? fatigueOnsetRep;
  final String? comment;
  final CalibrationSummary? calibrationSummary;
  final MuscleMap? muscleMap;
  final BalanceSummary? balanceSummary;
  final List<SetResult> setResults;

  const WorkoutSession({
    this.userId,
    required this.sessionId,
    required this.exerciseType,
    required this.status,
    required this.endReason,
    required this.startedAt,
    required this.endedAt,
    required this.durationSec,
    required this.setCount,
    required this.targetRepsPerSet,
    required this.actualRepsPerSet,
    required this.restSec,
    required this.totalReps,
    required this.validReps,
    required this.avgTargetMuscle,
    required this.avgAssistMuscle,
    required this.avgCompensator,
    required this.compensationCount,
    this.fatigueOnsetSet,
    this.fatigueOnsetRep,
    this.comment,
    this.calibrationSummary,
    this.muscleMap,
    this.balanceSummary,
    required this.setResults,
  });

  /// Pi로부터 온 payload 또는 서버에서 받아온 payload 변환
  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    // Pi에서 "sessionResult"로 래핑되어 올 경우 풀기 위한 로직 (옵션)
    final root = json.containsKey('sessionResult') ? json['sessionResult'] as Map<String, dynamic> : json;

    return WorkoutSession(
      userId: root['user_id'] as int?,
      sessionId: root['session_id'] as String,
      exerciseType: ExerciseType.fromWire(root['exercise_type'] as String),
      status: root['status'] as String,
      endReason: root['end_reason'] as String,
      startedAt: DateTime.parse(root['started_at'] as String),
      endedAt: DateTime.parse(root['ended_at'] as String),
      durationSec: root['duration_sec'] as int,
      setCount: root['set_count'] as int,
      targetRepsPerSet: (root['target_reps_per_set'] as List).cast<int>(),
      actualRepsPerSet: (root['actual_reps_per_set'] as List).cast<int>(),
      restSec: root['rest_sec'] as int,
      totalReps: root['total_reps'] as int,
      validReps: root['valid_reps'] as int,
      avgTargetMuscle: (root['avg_target_muscle'] as num).toDouble(),
      avgAssistMuscle: (root['avg_assist_muscle'] as num).toDouble(),
      avgCompensator: (root['avg_compensator'] as num).toDouble(),
      compensationCount: root['compensation_count'] as int,
      fatigueOnsetSet: root['fatigue_onset_set'] as int?,
      fatigueOnsetRep: root['fatigue_onset_rep'] as int?,
      comment: root['comment'] as String?,
      calibrationSummary: root['calibration_summary'] != null
          ? CalibrationSummary.fromJson(root['calibration_summary'] as Map<String, dynamic>)
          : null,
      muscleMap: root['muscle_map'] != null
          ? MuscleMap.fromJson(root['muscle_map'] as Map<String, dynamic>)
          : null,
      balanceSummary: root['balance_summary'] != null
          ? BalanceSummary.fromJson(root['balance_summary'] as Map<String, dynamic>)
          : null,
      // 백엔드는 set_results라는 키를 사용
      setResults: (root['set_results'] as List)
          .map((s) => SetResult.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 백엔드 전송 및 로컬 DB 저장용
  Map<String, dynamic> toJson() => {
        if (userId != null) 'user_id': userId,
        'session_id': sessionId,
        // enum 값을 소문자로 보내길 원하는 경우 (백엔드 스펙에 맞춤. 기본은 대분자이나 pushup 소문자 예시 따름)
        'exercise_type': exerciseType.wire.toLowerCase().replaceAll('_', ''), 
        'status': status,
        'end_reason': endReason,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
        'duration_sec': durationSec,
        'set_count': setCount,
        'target_reps_per_set': targetRepsPerSet,
        'actual_reps_per_set': actualRepsPerSet,
        'rest_sec': restSec,
        'total_reps': totalReps,
        'valid_reps': validReps,
        'avg_target_muscle': avgTargetMuscle,
        'avg_assist_muscle': avgAssistMuscle,
        'avg_compensator': avgCompensator,
        'compensation_count': compensationCount,
        if (fatigueOnsetSet != null) 'fatigue_onset_set': fatigueOnsetSet,
        if (fatigueOnsetRep != null) 'fatigue_onset_rep': fatigueOnsetRep,
        if (comment != null) 'comment': comment,
        if (calibrationSummary != null) 'calibration_summary': calibrationSummary!.toJson(),
        if (muscleMap != null) 'muscle_map': muscleMap!.toJson(),
        if (balanceSummary != null) 'balance_summary': balanceSummary!.toJson(),
        'set_results': setResults.map((s) => s.toJson()).toList(),
      };
      
  /// App 단에서 user_id를 주입하기 위한 편의 메서드
  WorkoutSession copyWithUserId(int uid) {
    return WorkoutSession(
      userId: uid,
      sessionId: sessionId,
      exerciseType: exerciseType,
      status: status,
      endReason: endReason,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSec: durationSec,
      setCount: setCount,
      targetRepsPerSet: targetRepsPerSet,
      actualRepsPerSet: actualRepsPerSet,
      restSec: restSec,
      totalReps: totalReps,
      validReps: validReps,
      avgTargetMuscle: avgTargetMuscle,
      avgAssistMuscle: avgAssistMuscle,
      avgCompensator: avgCompensator,
      compensationCount: compensationCount,
      fatigueOnsetSet: fatigueOnsetSet,
      fatigueOnsetRep: fatigueOnsetRep,
      comment: comment,
      calibrationSummary: calibrationSummary,
      muscleMap: muscleMap,
      balanceSummary: balanceSummary,
      setResults: setResults,
    );
  }
}

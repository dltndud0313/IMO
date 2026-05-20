import '../../domain/models/exercise_type.dart';
import '../../domain/models/set_result.dart';
import '../../domain/models/workout_session.dart';

class SessionResultDto {
  const SessionResultDto({
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
    this.muscleMap = const {},
    this.balanceSummary,
    this.setResults = const [],
  });

  final String sessionId;
  final String exerciseType;
  final String status;
  final String endReason;
  final String startedAt;
  final String endedAt;
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
  final SessionResultCalibrationSummaryDto? calibrationSummary;
  final Map<String, double> muscleMap;
  final SessionResultBalanceSummaryDto? balanceSummary;
  final List<SessionResultSetDto> setResults;

  factory SessionResultDto.fromJson(Map<String, dynamic> json) {
    final calibrationSummary = json['calibration_summary'];
    final balanceSummary = json['balance_summary'];

    return SessionResultDto(
      sessionId: _asString(json['session_id']),
      exerciseType: _asString(json['exercise_type']),
      status: _asString(json['status']),
      endReason: _asString(json['end_reason']),
      startedAt: _asString(json['started_at']),
      endedAt: _asString(json['ended_at']),
      durationSec: _asInt(json['duration_sec']),
      setCount: _asInt(json['set_count']),
      targetRepsPerSet: _asIntList(json['target_reps_per_set']),
      actualRepsPerSet: _asIntList(json['actual_reps_per_set']),
      restSec: _asInt(json['rest_sec']),
      totalReps: _asInt(json['total_reps']),
      validReps: _asInt(json['valid_reps']),
      avgTargetMuscle: _asDouble(json['avg_target_muscle']),
      avgAssistMuscle: _asDouble(json['avg_assist_muscle']),
      avgCompensator: _asDouble(json['avg_compensator']),
      compensationCount: _asInt(json['compensation_count']),
      fatigueOnsetSet: _asNullableInt(json['fatigue_onset_set']),
      fatigueOnsetRep: _asNullableInt(json['fatigue_onset_rep']),
      comment: json['comment'] as String?,
      calibrationSummary: calibrationSummary is Map<String, dynamic>
          ? SessionResultCalibrationSummaryDto.fromJson(calibrationSummary)
          : null,
      muscleMap: _asDoubleMap(json['muscle_map']),
      balanceSummary: balanceSummary is Map<String, dynamic>
          ? SessionResultBalanceSummaryDto.fromJson(balanceSummary)
          : null,
      setResults: _asObjectList(
        json['set_results'],
        SessionResultSetDto.fromJson,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'exercise_type': exerciseType,
        'status': status,
        'end_reason': endReason,
        'started_at': startedAt,
        'ended_at': endedAt,
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
        if (calibrationSummary != null)
          'calibration_summary': calibrationSummary!.toJson(),
        if (muscleMap.isNotEmpty) 'muscle_map': muscleMap,
        if (balanceSummary != null) 'balance_summary': balanceSummary!.toJson(),
        'set_results': setResults.map((set) => set.toJson()).toList(),
      };

  WorkoutSession toDomain() {
    return WorkoutSession(
      sessionId: sessionId,
      exerciseType: _toExerciseType(exerciseType),
      status: status,
      endReason: endReason,
      startedAt: DateTime.parse(startedAt),
      endedAt: DateTime.parse(endedAt),
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
      calibrationSummary: calibrationSummary?.toDomain(),
      muscleMap: _toDomainMuscleMap(muscleMap),
      balanceSummary: balanceSummary?.toDomain(),
      setResults: setResults.map((set) => set.toDomain()).toList(),
    );
  }
}

class SessionResultCalibrationSummaryDto {
  const SessionResultCalibrationSummaryDto({
    required this.ch1Mvc,
    required this.ch2Mvc,
    required this.ch3Mvc,
    required this.ch4Mvc,
  });

  final double ch1Mvc;
  final double ch2Mvc;
  final double ch3Mvc;
  final double ch4Mvc;

  factory SessionResultCalibrationSummaryDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return SessionResultCalibrationSummaryDto(
      ch1Mvc: _asDouble(json['ch1_mvc']),
      ch2Mvc: _asDouble(json['ch2_mvc']),
      ch3Mvc: _asDouble(json['ch3_mvc']),
      ch4Mvc: _asDouble(json['ch4_mvc']),
    );
  }

  Map<String, dynamic> toJson() => {
        'ch1_mvc': ch1Mvc,
        'ch2_mvc': ch2Mvc,
        'ch3_mvc': ch3Mvc,
        'ch4_mvc': ch4Mvc,
      };

  CalibrationSummary toDomain() {
    return CalibrationSummary(
      ch1Mvc: ch1Mvc,
      ch2Mvc: ch2Mvc,
      ch3Mvc: ch3Mvc,
      ch4Mvc: ch4Mvc,
    );
  }
}

class SessionResultBalanceSummaryDto {
  const SessionResultBalanceSummaryDto({
    required this.enabled,
    this.reason,
    this.leftValue,
    this.rightValue,
    this.diffValue,
    this.balanceLabel,
  });

  final bool enabled;
  final String? reason;
  final double? leftValue;
  final double? rightValue;
  final double? diffValue;
  final String? balanceLabel;

  factory SessionResultBalanceSummaryDto.fromJson(Map<String, dynamic> json) {
    return SessionResultBalanceSummaryDto(
      enabled: json['enabled'] as bool? ?? false,
      reason: json['reason'] as String?,
      leftValue: _asNullableDouble(json['left_value']),
      rightValue: _asNullableDouble(json['right_value']),
      diffValue: _asNullableDouble(json['diff_value']),
      balanceLabel: json['balance_label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (reason != null) 'reason': reason,
        if (leftValue != null) 'left_value': leftValue,
        if (rightValue != null) 'right_value': rightValue,
        if (diffValue != null) 'diff_value': diffValue,
        if (balanceLabel != null) 'balance_label': balanceLabel,
      };

  BalanceSummary toDomain() {
    return BalanceSummary(
      enabled: enabled,
      reason: reason ?? '',
      leftValue: leftValue,
      rightValue: rightValue,
      diffValue: diffValue,
      balanceLabel: balanceLabel,
    );
  }
}

class SessionResultSetDto {
  const SessionResultSetDto({
    required this.setIndex,
    required this.targetReps,
    required this.actualReps,
    required this.avgSpeed,
    required this.compensationCount,
    required this.startedAt,
    required this.endedAt,
  });

  final int setIndex;
  final int targetReps;
  final int actualReps;
  final String avgSpeed;
  final int compensationCount;
  final String startedAt;
  final String endedAt;

  factory SessionResultSetDto.fromJson(Map<String, dynamic> json) {
    return SessionResultSetDto(
      setIndex: _asInt(json['set_index']),
      targetReps: _asInt(json['target_reps']),
      actualReps: _asInt(json['actual_reps']),
      avgSpeed: _asString(json['avg_speed']),
      compensationCount: _asInt(json['compensation_count']),
      startedAt: _asString(json['started_at']),
      endedAt: _asString(json['ended_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'set_index': setIndex,
        'target_reps': targetReps,
        'actual_reps': actualReps,
        'avg_speed': avgSpeed,
        'compensation_count': compensationCount,
        'started_at': startedAt,
        'ended_at': endedAt,
      };

  SetResult toDomain() {
    return SetResult(
      setIndex: setIndex,
      targetReps: targetReps,
      actualReps: actualReps,
      compensationCount: compensationCount,
      avgSpeed: avgSpeed,
      startedAt: DateTime.parse(startedAt),
      endedAt: DateTime.parse(endedAt),
    );
  }
}

String _asString(Object? value) => value?.toString() ?? '';

int _asInt(Object? value) => switch (value) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };

int? _asNullableInt(Object? value) => value == null ? null : _asInt(value);

double _asDouble(Object? value) => switch (value) {
      double v => v,
      num v => v.toDouble(),
      String v => double.tryParse(v) ?? 0,
      _ => 0,
    };

double? _asNullableDouble(Object? value) {
  return value == null ? null : _asDouble(value);
}

List<int> _asIntList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map(_asInt).toList();
}

Map<String, double> _asDoubleMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return value.map((key, rawValue) {
    return MapEntry(key.toString(), _asDouble(rawValue));
  });
}

List<T> _asObjectList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

ExerciseType _toExerciseType(String value) {
  return switch (value.toLowerCase()) {
    'pushup' || 'push_up' => ExerciseType.pushUp,
    'bicep_curl' || 'bicepcurl' => ExerciseType.bicepCurl,
    'lateral_raise' || 'lateralraise' => ExerciseType.lateralRaise,
    _ => ExerciseType.fromWire(value),
  };
}

MuscleMap? _toDomainMuscleMap(Map<String, double> map) {
  if (map.isEmpty) {
    return null;
  }

  return MuscleMap(values: map);
}

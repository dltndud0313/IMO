import 'exercise_sensor_mapping.dart';
import 'muscle_map_schema.dart';
import 'workout_session.dart' as workout_session;

enum MuscleActivationLevel { inactive, low, normal, high, danger }

class MuscleMapEntry {
  const MuscleMapEntry({
    required this.key,
    required this.displayName,
    required this.value,
    required this.level,
    required this.kind,
    this.isKnownKey = true,
  });

  final String key;
  final String displayName;
  final double value;
  final MuscleActivationLevel level;
  final MuscleMapValueKind kind;
  final bool isKnownKey;

  /// value 는 이미 0~100 percent 라 표시값으로 그대로 쓴다.
  double get percentValue => value;
}

class MuscleMapState {
  const MuscleMapState({
    required this.exerciseId,
    required this.entries,
  });

  final String exerciseId;
  final List<MuscleMapEntry> entries;

  bool get isEmpty => entries.isEmpty;

  factory MuscleMapState.fromWorkoutSession(
    workout_session.WorkoutSession session, {
    bool includeMissingKeys = true,
  }) {
    return MuscleMapState.fromValues(
      exerciseId: session.exerciseType.wire,
      values: session.muscleMap?.values ?? const {},
      includeMissingKeys: includeMissingKeys,
    );
  }

  factory MuscleMapState.fromValues({
    required String exerciseId,
    required Map<String, double> values,
    bool includeMissingKeys = true,
  }) {
    final mapping = findExerciseSensorMapping(exerciseId);
    final schema = findExerciseMuscleMapSchema(exerciseId);
    final entries = <MuscleMapEntry>[];
    final knownKeys = <String>{};
    final allowedKeys = mapping?.muscleMapKeys ?? schema?.allowedKeys ?? const <String>[];

    if (allowedKeys.isNotEmpty) {
      for (final key in allowedKeys) {
        final definition = schema?.findKey(key);
        final kind = definition?.kind ?? MuscleMapValueKind.activation;
        knownKeys.add(key);
        if (!includeMissingKeys && !values.containsKey(key)) {
          continue;
        }

        final value = values[key] ?? 0;
        entries.add(
          MuscleMapEntry(
            key: key,
            displayName: definition?.displayName ?? key,
            value: _clampPercent(value),
            level: _toActivationLevel(
              classifyMuscleMapValue(value, kind: kind),
            ),
            kind: kind,
          ),
        );
      }
    }

    for (final entry in values.entries) {
      if (knownKeys.contains(entry.key)) {
        continue;
      }

      entries.add(
        MuscleMapEntry(
          key: entry.key,
          displayName: entry.key,
          value: _clampPercent(entry.value),
          level: _toActivationLevel(classifyMuscleMapValue(entry.value)),
          kind: MuscleMapValueKind.activation,
          isKnownKey: false,
        ),
      );
    }

    return MuscleMapState(
      exerciseId: exerciseId,
      entries: entries,
    );
  }
}

MuscleActivationLevel resolveMuscleActivationLevel(
  double value, {
  MuscleMapValueKind kind = MuscleMapValueKind.activation,
}) {
  return _toActivationLevel(classifyMuscleMapValue(value, kind: kind));
}

// 스케일 계약(2026-05-18 통일): 활성도 값은 0~100 percent.
double _clampPercent(double value) => value.clamp(0.0, 100.0).toDouble();

MuscleActivationLevel _toActivationLevel(MuscleMapStatus status) {
  return switch (status) {
    MuscleMapStatus.inactive => MuscleActivationLevel.inactive,
    MuscleMapStatus.low => MuscleActivationLevel.low,
    MuscleMapStatus.normal => MuscleActivationLevel.normal,
    MuscleMapStatus.high => MuscleActivationLevel.high,
    MuscleMapStatus.danger => MuscleActivationLevel.danger,
  };
}

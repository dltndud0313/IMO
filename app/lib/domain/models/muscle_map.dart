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

  double get percentValue => muscleMapRatioToPercent(value);
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
    final schema = findExerciseMuscleMapSchema(exerciseId);
    final entries = <MuscleMapEntry>[];
    final knownKeys = <String>{};

    if (schema != null) {
      for (final definition in schema.keys) {
        knownKeys.add(definition.key);
        if (!includeMissingKeys && !values.containsKey(definition.key)) {
          continue;
        }

        final value = values[definition.key] ?? 0;
        entries.add(
          MuscleMapEntry(
            key: definition.key,
            displayName: definition.displayName,
            value: _clampRatio(value),
            level: _toActivationLevel(
              classifyMuscleMapValue(value, kind: definition.kind),
            ),
            kind: definition.kind,
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
          value: _clampRatio(entry.value),
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

double _clampRatio(double value) => value.clamp(0.0, 1.0).toDouble();

MuscleActivationLevel _toActivationLevel(MuscleMapStatus status) {
  return switch (status) {
    MuscleMapStatus.inactive => MuscleActivationLevel.inactive,
    MuscleMapStatus.low => MuscleActivationLevel.low,
    MuscleMapStatus.normal => MuscleActivationLevel.normal,
    MuscleMapStatus.high => MuscleActivationLevel.high,
    MuscleMapStatus.danger => MuscleActivationLevel.danger,
  };
}

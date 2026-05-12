import '../../../domain/models/exercise_sensor_mapping.dart';
import '../../../domain/models/muscle_map_schema.dart';
import 'body_heatmap_region.dart';

const bodyHeatmapRegionKeys = <String>[
  'left_chest',
  'right_chest',
  'left_triceps',
  'right_triceps',
  'left_biceps',
  'right_biceps',
  'left_forearm',
  'right_forearm',
  'left_lateral_deltoid',
  'right_lateral_deltoid',
  'left_upper_trapezius',
  'right_upper_trapezius',
  'trunk',
];

const _viewSideByKey = <String, BodyHeatmapViewSide>{
  'left_chest': BodyHeatmapViewSide.front,
  'right_chest': BodyHeatmapViewSide.front,
  'left_biceps': BodyHeatmapViewSide.front,
  'right_biceps': BodyHeatmapViewSide.front,
  'left_forearm': BodyHeatmapViewSide.front,
  'right_forearm': BodyHeatmapViewSide.front,
  'left_triceps': BodyHeatmapViewSide.back,
  'right_triceps': BodyHeatmapViewSide.back,
  'left_lateral_deltoid': BodyHeatmapViewSide.front,
  'right_lateral_deltoid': BodyHeatmapViewSide.front,
  'left_upper_trapezius': BodyHeatmapViewSide.back,
  'right_upper_trapezius': BodyHeatmapViewSide.back,
  'trunk': BodyHeatmapViewSide.posture,
};

const _legacyKeyAliases = <String, String>{
  'chest_left': 'left_chest',
  'chest_right': 'right_chest',
  'left_pectoralis_major': 'left_chest',
  'right_pectoralis_major': 'right_chest',
  'pectoralis_major_left': 'left_chest',
  'pectoralis_major_right': 'right_chest',
  'triceps_left': 'left_triceps',
  'triceps_right': 'right_triceps',
  'biceps_left': 'left_biceps',
  'biceps_right': 'right_biceps',
  'forearm_left': 'left_forearm',
  'forearm_right': 'right_forearm',
  'deltoid_left': 'left_lateral_deltoid',
  'deltoid_right': 'right_lateral_deltoid',
  'lateral_deltoid_left': 'left_lateral_deltoid',
  'lateral_deltoid_right': 'right_lateral_deltoid',
  'upper_trapezius_left': 'left_upper_trapezius',
  'upper_trapezius_right': 'right_upper_trapezius',
};

List<BodyHeatmapRegion> buildBodyHeatmapRegionsFromData(
  Map<String, dynamic>? data, {
  String? exerciseId,
  bool includeMissingKeys = true,
}) {
  final resolvedExerciseId = _resolveExerciseId(data, exerciseId);
  final schema = resolvedExerciseId == null
      ? null
      : findExerciseMuscleMapSchema(resolvedExerciseId);
  final rawByKey = _indexRawMuscles(data);
  final keys = _resolveRegionKeys(resolvedExerciseId, includeMissingKeys);
  final regions = <BodyHeatmapRegion>[];
  final emittedKeys = <String>{};

  for (final key in keys) {
    emittedKeys.add(key);
    final raw = rawByKey[key];
    regions.add(
      _buildRegion(
        key: key,
        raw: raw,
        definition: schema?.findKey(key),
        isKnownKey: bodyHeatmapRegionKeys.contains(key),
      ),
    );
  }

  for (final entry in rawByKey.entries) {
    if (emittedKeys.contains(entry.key)) {
      continue;
    }

    regions.add(
      _buildRegion(
        key: entry.key,
        raw: entry.value,
        definition: schema?.findKey(entry.key),
        isKnownKey: bodyHeatmapRegionKeys.contains(entry.key),
      ),
    );
  }

  return regions;
}

double? normalizeHeatmapActivation(Object? value) {
  final number = _asDouble(value);
  if (number == null || !number.isFinite) {
    return null;
  }

  if (number <= 1.0) {
    return (number * 100).clamp(0.0, 100.0).toDouble();
  }

  return number.clamp(0.0, 100.0).toDouble();
}

String normalizeBodyHeatmapKey(String key) {
  final normalized = key.trim().toLowerCase().replaceAll('-', '_');
  return _legacyKeyAliases[normalized] ?? normalized;
}

BodyHeatmapViewSide bodyHeatmapViewSideForKey(String key) {
  return _viewSideByKey[normalizeBodyHeatmapKey(key)] ??
      BodyHeatmapViewSide.both;
}

List<String> _resolveRegionKeys(String? exerciseId, bool includeMissingKeys) {
  if (!includeMissingKeys) {
    return const <String>[];
  }

  final mapping = exerciseId == null
      ? null
      : findExerciseSensorMapping(exerciseId);
  return mapping?.muscleMapKeys ?? bodyHeatmapRegionKeys;
}

String? _resolveExerciseId(Map<String, dynamic>? data, String? exerciseId) {
  final explicit = exerciseId?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  final raw =
      data?['exerciseId'] ??
      data?['exercise_id'] ??
      data?['exerciseType'] ??
      data?['exercise_type'];
  final resolved = raw?.toString().trim();
  return resolved == null || resolved.isEmpty ? null : resolved;
}

Map<String, _RawHeatmapMuscle> _indexRawMuscles(Map<String, dynamic>? data) {
  final rawList = data?['muscles'];
  if (rawList is! List) {
    return const {};
  }

  final indexed = <String, _RawHeatmapMuscle>{};
  for (final item in rawList.whereType<Map>()) {
    final raw = Map<String, dynamic>.from(item);
    final rawKey =
        raw['muscleMapKey'] ??
        raw['muscle_map_key'] ??
        raw['muscleId'] ??
        raw['muscle_id'] ??
        raw['key'];
    if (rawKey == null) {
      continue;
    }

    final key = normalizeBodyHeatmapKey(rawKey.toString());
    if (key.isEmpty) {
      continue;
    }

    final next = _RawHeatmapMuscle.fromJson(raw);
    final current = indexed[key];
    indexed[key] = current == null ? next : current.merge(next);
  }

  return indexed;
}

BodyHeatmapRegion _buildRegion({
  required String key,
  required _RawHeatmapMuscle? raw,
  required MuscleMapKeyDefinition? definition,
  required bool isKnownKey,
}) {
  final viewSide = bodyHeatmapViewSideForKey(key);
  final inferredKind = viewSide == BodyHeatmapViewSide.posture
      ? MuscleMapValueKind.postureStability
      : MuscleMapValueKind.activation;

  return BodyHeatmapRegion(
    key: key,
    displayName: raw?.displayName ?? definition?.displayName ?? key,
    viewSide: viewSide,
    kind: definition?.kind ?? inferredKind,
    percent: raw?.percent,
    sessionCount: raw?.sessionCount ?? 0,
    isKnownKey: isKnownKey,
  );
}

double? _asDouble(Object? value) {
  return switch (value) {
    double v => v,
    num v => v.toDouble(),
    String v => double.tryParse(v),
    _ => null,
  };
}

int _asInt(Object? value) {
  return switch (value) {
    int v => v,
    num v => v.toInt(),
    String v => int.tryParse(v) ?? 0,
    _ => 0,
  };
}

class _RawHeatmapMuscle {
  const _RawHeatmapMuscle({
    required this.displayName,
    required this.percent,
    required this.sessionCount,
  });

  final String? displayName;
  final double? percent;
  final int sessionCount;

  factory _RawHeatmapMuscle.fromJson(Map<String, dynamic> json) {
    final rawName = json['muscleName'] ?? json['muscle_name'];
    return _RawHeatmapMuscle(
      displayName: rawName?.toString(),
      percent: normalizeHeatmapActivation(json['avgActivation']),
      sessionCount: _asInt(json['sessionCount'] ?? json['session_count']),
    );
  }

  _RawHeatmapMuscle merge(_RawHeatmapMuscle other) {
    return _RawHeatmapMuscle(
      displayName: displayName ?? other.displayName,
      percent: percent ?? other.percent,
      sessionCount: sessionCount >= other.sessionCount
          ? sessionCount
          : other.sessionCount,
    );
  }
}

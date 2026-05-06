enum MuscleMapValueKind { activation, postureStability }

enum MuscleMapStatus { inactive, low, normal, high, danger }

class MuscleMapKeyDefinition {
  const MuscleMapKeyDefinition({
    required this.key,
    required this.displayName,
    required this.kind,
    required this.description,
  });

  final String key;
  final String displayName;
  final MuscleMapValueKind kind;
  final String description;
}

class ExerciseMuscleMapSchema {
  const ExerciseMuscleMapSchema({
    required this.exerciseId,
    required this.displayName,
    required this.keys,
  });

  final String exerciseId;
  final String displayName;
  final List<MuscleMapKeyDefinition> keys;

  List<String> get allowedKeys => keys.map((entry) => entry.key).toList();

  MuscleMapKeyDefinition? findKey(String key) {
    for (final entry in keys) {
      if (entry.key == key) {
        return entry;
      }
    }
    return null;
  }
}

const exerciseMuscleMapSchemas = <String, ExerciseMuscleMapSchema>{
  'pushup': ExerciseMuscleMapSchema(
    exerciseId: 'pushup',
    displayName: '푸시업',
    keys: [
      MuscleMapKeyDefinition(
        key: 'left_chest',
        displayName: '왼쪽 대흉근',
        kind: MuscleMapValueKind.activation,
        description: '왼쪽 주동근 활성도',
      ),
      MuscleMapKeyDefinition(
        key: 'right_chest',
        displayName: '오른쪽 대흉근',
        kind: MuscleMapValueKind.activation,
        description: '오른쪽 주동근 활성도',
      ),
      MuscleMapKeyDefinition(
        key: 'left_triceps',
        displayName: '왼쪽 삼두근',
        kind: MuscleMapValueKind.activation,
        description: '왼쪽 보조근/보상근 개입',
      ),
      MuscleMapKeyDefinition(
        key: 'right_triceps',
        displayName: '오른쪽 삼두근',
        kind: MuscleMapValueKind.activation,
        description: '오른쪽 보조근/보상근 개입',
      ),
      MuscleMapKeyDefinition(
        key: 'trunk',
        displayName: '몸통 안정성',
        kind: MuscleMapValueKind.postureStability,
        description: '몸통 정렬, 흔들림, 반동 보상',
      ),
    ],
  ),
  'bicep_curl': ExerciseMuscleMapSchema(
    exerciseId: 'bicep_curl',
    displayName: '이두컬',
    keys: [
      MuscleMapKeyDefinition(
        key: 'left_biceps',
        displayName: '왼쪽 이두근',
        kind: MuscleMapValueKind.activation,
        description: '왼쪽 주동근 활성도',
      ),
      MuscleMapKeyDefinition(
        key: 'right_biceps',
        displayName: '오른쪽 이두근',
        kind: MuscleMapValueKind.activation,
        description: '오른쪽 주동근 활성도',
      ),
      MuscleMapKeyDefinition(
        key: 'left_forearm',
        displayName: '왼쪽 전완근',
        kind: MuscleMapValueKind.activation,
        description: '왼쪽 전완 과개입 확인',
      ),
      MuscleMapKeyDefinition(
        key: 'right_forearm',
        displayName: '오른쪽 전완근',
        kind: MuscleMapValueKind.activation,
        description: '오른쪽 전완 과개입 확인',
      ),
      MuscleMapKeyDefinition(
        key: 'trunk',
        displayName: '몸통 안정성',
        kind: MuscleMapValueKind.postureStability,
        description: '몸통 반동, 팔꿈치 축 흔들림',
      ),
    ],
  ),
  'lateral_raise': ExerciseMuscleMapSchema(
    exerciseId: 'lateral_raise',
    displayName: '사이드 레터럴 레이즈',
    keys: [
      MuscleMapKeyDefinition(
        key: 'left_lateral_deltoid',
        displayName: '왼쪽 측면 삼각근',
        kind: MuscleMapValueKind.activation,
        description: '왼쪽 주동근 활성도',
      ),
      MuscleMapKeyDefinition(
        key: 'right_lateral_deltoid',
        displayName: '오른쪽 측면 삼각근',
        kind: MuscleMapValueKind.activation,
        description: '오른쪽 주동근 활성도',
      ),
      MuscleMapKeyDefinition(
        key: 'left_upper_trapezius',
        displayName: '왼쪽 상부 승모근',
        kind: MuscleMapValueKind.activation,
        description: '왼쪽 승모근 보상 여부',
      ),
      MuscleMapKeyDefinition(
        key: 'right_upper_trapezius',
        displayName: '오른쪽 상부 승모근',
        kind: MuscleMapValueKind.activation,
        description: '오른쪽 승모근 보상 여부',
      ),
      MuscleMapKeyDefinition(
        key: 'trunk',
        displayName: '몸통 안정성',
        kind: MuscleMapValueKind.postureStability,
        description: '몸통 흔들림, 반동 사용',
      ),
    ],
  ),
};

ExerciseMuscleMapSchema? findExerciseMuscleMapSchema(String exerciseId) {
  final normalized = exerciseId.trim().toLowerCase().replaceAll('-', '_');
  final compact = normalized.replaceAll('_', '');

  return switch (compact) {
    'pushup' => exerciseMuscleMapSchemas['pushup'],
    'bicepcurl' => exerciseMuscleMapSchemas['bicep_curl'],
    'lateralraise' => exerciseMuscleMapSchemas['lateral_raise'],
    _ => null,
  };
}

MuscleMapStatus classifyMuscleMapValue(
  double value, {
  MuscleMapValueKind kind = MuscleMapValueKind.activation,
}) {
  final clamped = value.clamp(0.0, 1.0).toDouble();
  if (clamped == 0) {
    return MuscleMapStatus.inactive;
  }

  if (kind == MuscleMapValueKind.postureStability) {
    if (clamped < 0.3) return MuscleMapStatus.danger;
    if (clamped < 0.5) return MuscleMapStatus.low;
    if (clamped < 0.75) return MuscleMapStatus.normal;
    return MuscleMapStatus.high;
  }

  if (clamped < 0.4) return MuscleMapStatus.low;
  if (clamped < 0.7) return MuscleMapStatus.normal;
  if (clamped < 0.9) return MuscleMapStatus.high;
  return MuscleMapStatus.danger;
}

double muscleMapRatioToPercent(double value) {
  return value.clamp(0.0, 1.0).toDouble() * 100;
}

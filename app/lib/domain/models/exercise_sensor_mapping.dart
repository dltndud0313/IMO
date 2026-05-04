import 'exercise_type.dart' show ExerciseType;
import 'sensor_placement.dart';

class ExerciseSensorMapping {
  const ExerciseSensorMapping({
    required this.exerciseId,
    required this.exerciseType,
    required this.displayName,
    required this.placements,
    required this.muscleMapKeys,
  });

  final String exerciseId;
  final ExerciseType exerciseType;
  final String displayName;
  final List<SensorPlacement> placements;
  final List<String> muscleMapKeys;

  List<SensorPlacement> get emgPlacements {
    return placements
        .where((placement) => placement.channelType == SensorChannelType.emg)
        .toList();
  }

  List<SensorPlacement> get imuPlacements {
    return placements
        .where((placement) => placement.channelType == SensorChannelType.imu)
        .toList();
  }
}

const exerciseSensorMappings = <String, ExerciseSensorMapping>{
  'pushup': ExerciseSensorMapping(
    exerciseId: 'pushup',
    exerciseType: ExerciseType.pushUp,
    displayName: '푸시업',
    muscleMapKeys: [
      'left_chest',
      'right_chest',
      'left_triceps',
      'right_triceps',
      'trunk',
    ],
    placements: [
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 1,
        side: SensorSide.left,
        fixedRole: '왼쪽 주동근',
        displayName: '왼쪽 대흉근',
        dataKey: 'left_chest',
        attachmentLocation: '왼쪽 가슴 대흉근 부위',
        analysisPurpose: '왼쪽 주동근 활성도',
      ),
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 2,
        side: SensorSide.right,
        fixedRole: '오른쪽 주동근',
        displayName: '오른쪽 대흉근',
        dataKey: 'right_chest',
        attachmentLocation: '오른쪽 가슴 대흉근 부위',
        analysisPurpose: '오른쪽 주동근 활성도',
      ),
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 3,
        side: SensorSide.left,
        fixedRole: '왼쪽 보조/보상근',
        displayName: '왼쪽 삼두근',
        dataKey: 'left_triceps',
        attachmentLocation: '왼쪽 상완 뒤쪽 삼두근 부위',
        analysisPurpose: '왼쪽 보조근/보상근 개입',
      ),
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 4,
        side: SensorSide.right,
        fixedRole: '오른쪽 보조/보상근',
        displayName: '오른쪽 삼두근',
        dataKey: 'right_triceps',
        attachmentLocation: '오른쪽 상완 뒤쪽 삼두근 부위',
        analysisPurpose: '오른쪽 보조근/보상근 개입',
      ),
      SensorPlacement(
        channelType: SensorChannelType.imu,
        channelNumber: 1,
        side: SensorSide.center,
        fixedRole: '몸통',
        displayName: '몸통',
        dataKey: 'trunk',
        attachmentLocation: '흉추 상부 또는 상부 등판 중앙',
        analysisPurpose: '상체 정렬, 허리/몸통 흔들림',
      ),
      SensorPlacement(
        channelType: SensorChannelType.imu,
        channelNumber: 2,
        side: SensorSide.left,
        fixedRole: '왼쪽 팔',
        displayName: '왼쪽 상완',
        dataKey: 'left_upper_arm',
        attachmentLocation: '왼쪽 상완 바깥쪽',
        analysisPurpose: '왼팔 궤적, 좌우 비대칭',
      ),
      SensorPlacement(
        channelType: SensorChannelType.imu,
        channelNumber: 3,
        side: SensorSide.right,
        fixedRole: '오른쪽 팔',
        displayName: '오른쪽 상완',
        dataKey: 'right_upper_arm',
        attachmentLocation: '오른쪽 상완 바깥쪽',
        analysisPurpose: '오른팔 궤적, 좌우 비대칭',
      ),
    ],
  ),
  'bicep_curl': ExerciseSensorMapping(
    exerciseId: 'bicep_curl',
    exerciseType: ExerciseType.bicepCurl,
    displayName: '이두컬',
    muscleMapKeys: [
      'left_biceps',
      'right_biceps',
      'left_forearm',
      'right_forearm',
      'trunk',
    ],
    placements: [
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 1,
        side: SensorSide.left,
        fixedRole: '왼쪽 주동근',
        displayName: '왼쪽 이두근',
        dataKey: 'left_biceps',
        attachmentLocation: '왼쪽 상완 앞쪽 이두근 부위',
        analysisPurpose: '왼쪽 주동근 활성도',
      ),
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 2,
        side: SensorSide.right,
        fixedRole: '오른쪽 주동근',
        displayName: '오른쪽 이두근',
        dataKey: 'right_biceps',
        attachmentLocation: '오른쪽 상완 앞쪽 이두근 부위',
        analysisPurpose: '오른쪽 주동근 활성도',
      ),
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 3,
        side: SensorSide.left,
        fixedRole: '왼쪽 보조/보상근',
        displayName: '왼쪽 전완근',
        dataKey: 'left_forearm',
        attachmentLocation: '왼쪽 전완 앞쪽 또는 바깥쪽',
        analysisPurpose: '왼쪽 전완 과개입 확인',
      ),
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 4,
        side: SensorSide.right,
        fixedRole: '오른쪽 보조/보상근',
        displayName: '오른쪽 전완근',
        dataKey: 'right_forearm',
        attachmentLocation: '오른쪽 전완 앞쪽 또는 바깥쪽',
        analysisPurpose: '오른쪽 전완 과개입 확인',
      ),
      SensorPlacement(
        channelType: SensorChannelType.imu,
        channelNumber: 1,
        side: SensorSide.left,
        fixedRole: '왼쪽 팔',
        displayName: '왼쪽 전완',
        dataKey: 'left_forearm_motion',
        attachmentLocation: '왼쪽 손목 또는 전완',
        analysisPurpose: '왼팔 컬 궤적, 속도',
      ),
      SensorPlacement(
        channelType: SensorChannelType.imu,
        channelNumber: 2,
        side: SensorSide.right,
        fixedRole: '오른쪽 팔',
        displayName: '오른쪽 전완',
        dataKey: 'right_forearm_motion',
        attachmentLocation: '오른쪽 손목 또는 전완',
        analysisPurpose: '오른팔 컬 궤적, 속도',
      ),
      SensorPlacement(
        channelType: SensorChannelType.imu,
        channelNumber: 3,
        side: SensorSide.center,
        fixedRole: '몸통',
        displayName: '몸통',
        dataKey: 'trunk',
        attachmentLocation: '흉추 상부 또는 가슴 중앙 근처 몸통',
        analysisPurpose: '몸통 반동, 팔꿈치 축 흔들림',
      ),
    ],
  ),
  'lateral_raise': ExerciseSensorMapping(
    exerciseId: 'lateral_raise',
    exerciseType: ExerciseType.lateralRaise,
    displayName: '사이드 레터럴 레이즈',
    muscleMapKeys: [
      'left_lateral_deltoid',
      'right_lateral_deltoid',
      'left_upper_trapezius',
      'right_upper_trapezius',
      'trunk',
    ],
    placements: [
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 1,
        side: SensorSide.left,
        fixedRole: '왼쪽 주동근',
        displayName: '왼쪽 측면 삼각근',
        dataKey: 'left_lateral_deltoid',
        attachmentLocation: '왼쪽 어깨 측면 삼각근 부위',
        analysisPurpose: '왼쪽 주동근 활성도',
      ),
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 2,
        side: SensorSide.right,
        fixedRole: '오른쪽 주동근',
        displayName: '오른쪽 측면 삼각근',
        dataKey: 'right_lateral_deltoid',
        attachmentLocation: '오른쪽 어깨 측면 삼각근 부위',
        analysisPurpose: '오른쪽 주동근 활성도',
      ),
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 3,
        side: SensorSide.left,
        fixedRole: '왼쪽 보조/보상근',
        displayName: '왼쪽 상부 승모근',
        dataKey: 'left_upper_trapezius',
        attachmentLocation: '왼쪽 목-어깨 사이 상부 승모근 부위',
        analysisPurpose: '왼쪽 승모근 보상 여부',
      ),
      SensorPlacement(
        channelType: SensorChannelType.emg,
        channelNumber: 4,
        side: SensorSide.right,
        fixedRole: '오른쪽 보조/보상근',
        displayName: '오른쪽 상부 승모근',
        dataKey: 'right_upper_trapezius',
        attachmentLocation: '오른쪽 목-어깨 사이 상부 승모근 부위',
        analysisPurpose: '오른쪽 승모근 보상 여부',
      ),
      SensorPlacement(
        channelType: SensorChannelType.imu,
        channelNumber: 1,
        side: SensorSide.left,
        fixedRole: '왼쪽 팔',
        displayName: '왼쪽 전완',
        dataKey: 'left_forearm_motion',
        attachmentLocation: '왼쪽 손목 또는 전완',
        analysisPurpose: '왼팔 들어올림 각도, 반동',
      ),
      SensorPlacement(
        channelType: SensorChannelType.imu,
        channelNumber: 2,
        side: SensorSide.right,
        fixedRole: '오른쪽 팔',
        displayName: '오른쪽 전완',
        dataKey: 'right_forearm_motion',
        attachmentLocation: '오른쪽 손목 또는 전완',
        analysisPurpose: '오른팔 들어올림 각도, 반동',
      ),
      SensorPlacement(
        channelType: SensorChannelType.imu,
        channelNumber: 3,
        side: SensorSide.center,
        fixedRole: '몸통',
        displayName: '몸통',
        dataKey: 'trunk',
        attachmentLocation: '흉추 상부 또는 등판 중앙',
        analysisPurpose: '몸통 흔들림, 반동 사용',
      ),
    ],
  ),
};

ExerciseSensorMapping? findExerciseSensorMapping(String exerciseId) {
  final normalized = exerciseId.trim().toLowerCase().replaceAll('-', '_');
  final compact = normalized.replaceAll('_', '');

  return switch (compact) {
    'pushup' => exerciseSensorMappings['pushup'],
    'bicepcurl' => exerciseSensorMappings['bicep_curl'],
    'lateralraise' => exerciseSensorMappings['lateral_raise'],
    _ => null,
  };
}

ExerciseSensorMapping exerciseSensorMappingOrDefault(String exerciseId) {
  return findExerciseSensorMapping(exerciseId) ??
      exerciseSensorMappings['pushup']!;
}

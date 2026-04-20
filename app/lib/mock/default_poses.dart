import 'dart:ui';

import '../models/pose_data.dart';

/// 테스트용 기본 아바타 포즈 (정규화 좌표 0~1).
/// 차렷 자세로 정면을 바라보는 사람을 가정.
/// 추후 실제 ML Kit 결과로 대체될 예정.
class DefaultPoses {
  /// 기본 남성 아바타 — 어깨 넓고 골반 좁음
  static final PoseData male = PoseData(
    landmarks: const {
      'nose': Offset(0.50, 0.08),
      'leftShoulder': Offset(0.34, 0.22),
      'rightShoulder': Offset(0.66, 0.22),
      'leftElbow': Offset(0.28, 0.35),
      'rightElbow': Offset(0.72, 0.35),
      'leftWrist': Offset(0.25, 0.48),
      'rightWrist': Offset(0.75, 0.48),
      'leftHip': Offset(0.40, 0.52),
      'rightHip': Offset(0.60, 0.52),
      'leftKnee': Offset(0.40, 0.74),
      'rightKnee': Offset(0.60, 0.74),
      'leftAnkle': Offset(0.40, 0.94),
      'rightAnkle': Offset(0.60, 0.94),
    },
  );

  /// 기본 여성 아바타 — 어깨 좁고 골반 넓음
  static final PoseData female = PoseData(
    landmarks: const {
      'nose': Offset(0.50, 0.08),
      'leftShoulder': Offset(0.38, 0.22),
      'rightShoulder': Offset(0.62, 0.22),
      'leftElbow': Offset(0.33, 0.35),
      'rightElbow': Offset(0.67, 0.35),
      'leftWrist': Offset(0.30, 0.48),
      'rightWrist': Offset(0.70, 0.48),
      'leftHip': Offset(0.36, 0.52),
      'rightHip': Offset(0.64, 0.52),
      'leftKnee': Offset(0.40, 0.74),
      'rightKnee': Offset(0.60, 0.74),
      'leftAnkle': Offset(0.40, 0.94),
      'rightAnkle': Offset(0.60, 0.94),
    },
  );

  static PoseData byGender(String gender) =>
      gender == 'F' ? female : male;
}

import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_data.dart';

/// ML Kit Pose Detection 래퍼.
/// 이미지 파일을 받아 정규화된 PoseData를 반환한다.
class PoseDetectionService {
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.single,
      model: PoseDetectionModel.accurate,
    ),
  );

  /// 이미지에서 포즈 감지.
  /// 포즈가 검출되지 않으면 null 반환.
  Future<PoseData?> detectFromFile(File imageFile) async {
    final input = InputImage.fromFile(imageFile);
    final poses = await _detector.processImage(input);
    if (poses.isEmpty) return null;

    // 이미지 크기를 알아야 정규화 가능
    final bytes = await imageFile.readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width.toDouble();
    final h = frame.image.height.toDouble();
    frame.image.dispose();

    final pose = poses.first;
    final map = <String, Offset>{};
    pose.landmarks.forEach((type, lm) {
      map[type.name] = Offset(lm.x / w, lm.y / h);
    });
    return PoseData(landmarks: map);
  }

  Future<void> dispose() async {
    await _detector.close();
  }
}

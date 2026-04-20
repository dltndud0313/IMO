import 'package:flutter/material.dart';

import '../models/pose_data.dart';

/// EMG 채널과 매핑할 근육 영역.
class MuscleChannel {
  final String label;
  final String muscleName;
  final double intensity; // 0~1
  const MuscleChannel({
    required this.label,
    required this.muscleName,
    required this.intensity,
  });
}

/// 신체 부위별로 어떤 채널이 매핑되는지.
/// key = region 이름 ('torso', 'upperArm', 'forearm', 'shoulder',
///   'thighUpper', 'thighLower', 'calf')
/// value = null이면 기본 색, MuscleChannel이면 활성도 색
typedef RegionMap = Map<String, MuscleChannel?>;

/// 포즈 랜드마크를 사람 실루엣으로 그리고
/// 신체 부위별 채널 색상을 표현하는 CustomPainter.
class AvatarPainter extends CustomPainter {
  final PoseData pose;
  /// region 이름 → 채널. 없는 region은 기본 회색.
  final RegionMap regions;

  AvatarPainter({required this.pose, this.regions = const {}});

  static const _bodyColor = Color(0xFFD8DEE6);
  static const _bodyOutline = Color(0xFF8A94A6);

  Offset? _p(String key, Size size) {
    final o = pose.get(key);
    if (o == null) return null;
    return Offset(o.dx * size.width, o.dy * size.height);
  }

  Color _regionColor(String region) {
    final ch = regions[region];
    if (ch == null) return _bodyColor;
    final t = ch.intensity.clamp(0.0, 1.0);
    return Color.lerp(Colors.blue, Colors.red, t)!;
  }

  void _drawLimb(Canvas canvas, Offset a, Offset b, double width, Color color) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawLimbWithOutline(
    Canvas canvas, Offset a, Offset b, double width, Color color,
  ) {
    _drawLimb(canvas, a, b, width + 2, _bodyOutline);
    _drawLimb(canvas, a, b, width, color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lShoulder = _p('leftShoulder', size);
    final rShoulder = _p('rightShoulder', size);
    final lHip = _p('leftHip', size);
    final rHip = _p('rightHip', size);
    final lElbow = _p('leftElbow', size);
    final rElbow = _p('rightElbow', size);
    final lWrist = _p('leftWrist', size);
    final rWrist = _p('rightWrist', size);
    final lKnee = _p('leftKnee', size);
    final rKnee = _p('rightKnee', size);
    final lAnkle = _p('leftAnkle', size);
    final rAnkle = _p('rightAnkle', size);
    final nose = _p('nose', size);

    if (lShoulder == null || rShoulder == null ||
        lHip == null || rHip == null) {
      const tp = TextSpan(
        text: '포즈를 그릴 수 없습니다',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      );
      final painter = TextPainter(text: tp, textDirection: TextDirection.ltr)
        ..layout();
      painter.paint(
        canvas,
        Offset((size.width - painter.width) / 2, size.height / 2),
      );
      return;
    }

    final shoulderWidth = (rShoulder - lShoulder).distance;
    final limbWidth = shoulderWidth * 0.28;

    final torsoColor = _regionColor('torso');
    final shoulderColor = _regionColor('shoulder');
    final upperArmColor = _regionColor('upperArm');
    final forearmColor = _regionColor('forearm');
    final thighUpperColor = _regionColor('thighUpper');
    final thighLowerColor = _regionColor('thighLower');
    final calfColor = _regionColor('calf');

    // --- 1) 몸통 ---
    final torsoPath = Path()
      ..moveTo(lShoulder.dx, lShoulder.dy)
      ..lineTo(rShoulder.dx, rShoulder.dy)
      ..lineTo(rHip.dx, rHip.dy)
      ..lineTo(lHip.dx, lHip.dy)
      ..close();
    canvas.drawPath(
      torsoPath,
      Paint()..color = torsoColor..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      torsoPath,
      Paint()
        ..color = _bodyOutline
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // --- 2) 어깨 관절 (작은 원) ---
    final shoulderRadius = shoulderWidth * 0.12;
    canvas.drawCircle(lShoulder, shoulderRadius,
        Paint()..color = shoulderColor);
    canvas.drawCircle(rShoulder, shoulderRadius,
        Paint()..color = shoulderColor);
    canvas.drawCircle(lShoulder, shoulderRadius,
        Paint()..color = _bodyOutline..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(rShoulder, shoulderRadius,
        Paint()..color = _bodyOutline..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // --- 3) 머리 ---
    final shoulderCenter = Offset(
      (lShoulder.dx + rShoulder.dx) / 2,
      (lShoulder.dy + rShoulder.dy) / 2,
    );
    final headRadius = shoulderWidth * 0.35;
    final headCenter = nose ??
        Offset(shoulderCenter.dx, shoulderCenter.dy - headRadius * 1.4);
    _drawLimbWithOutline(
      canvas, shoulderCenter,
      Offset(headCenter.dx, headCenter.dy + headRadius * 0.6),
      limbWidth * 0.7, _bodyColor,
    );
    canvas.drawCircle(headCenter, headRadius,
        Paint()..color = _bodyColor..style = PaintingStyle.fill);
    canvas.drawCircle(headCenter, headRadius,
        Paint()..color = _bodyOutline..strokeWidth = 2..style = PaintingStyle.stroke);

    // --- 4) 팔 (upperArm: 어깨→팔꿈치, forearm: 팔꿈치→손목) ---
    if (lElbow != null) {
      _drawLimbWithOutline(canvas, lShoulder, lElbow, limbWidth, upperArmColor);
      if (lWrist != null) {
        _drawLimbWithOutline(canvas, lElbow, lWrist, limbWidth, forearmColor);
      }
    }
    if (rElbow != null) {
      _drawLimbWithOutline(canvas, rShoulder, rElbow, limbWidth, upperArmColor);
      if (rWrist != null) {
        _drawLimbWithOutline(canvas, rElbow, rWrist, limbWidth, forearmColor);
      }
    }

    // --- 5) 다리 ---
    if (lKnee != null && rKnee != null) {
      final lMid = Offset.lerp(lHip, lKnee, 0.5)!;
      final rMid = Offset.lerp(rHip, rKnee, 0.5)!;

      // 허벅지 상단
      _drawLimbWithOutline(canvas, lHip, lMid, limbWidth, thighUpperColor);
      _drawLimbWithOutline(canvas, rHip, rMid, limbWidth, thighUpperColor);
      // 허벅지 하단
      _drawLimbWithOutline(canvas, lMid, lKnee, limbWidth, thighLowerColor);
      _drawLimbWithOutline(canvas, rMid, rKnee, limbWidth, thighLowerColor);
      // 종아리
      if (lAnkle != null) {
        _drawLimbWithOutline(canvas, lKnee, lAnkle, limbWidth, calfColor);
      }
      if (rAnkle != null) {
        _drawLimbWithOutline(canvas, rKnee, rAnkle, limbWidth, calfColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) => true;
}

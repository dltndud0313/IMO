import 'package:flutter/material.dart';

/// 운동별 동작 실루엣 아이콘. id로 적절한 CustomPainter 선택.
class ExerciseIcon extends StatelessWidget {
  final String exerciseId;
  final double size;
  final Color color;
  const ExerciseIcon({
    super.key,
    required this.exerciseId,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _painterFor(exerciseId, color),
      ),
    );
  }

  CustomPainter _painterFor(String id, Color c) {
    switch (id) {
      case 'pushup':
        return _PushupPainter(c);
      case 'curl':
        return _CurlPainter(c);
      case 'lateral_raise':
        return _LateralRaisePainter(c);
      case 'shoulder_rehab':
        return _ShoulderRehabPainter(c);
      default:
        return _DefaultPainter(c);
    }
  }
}

// ─────────── 공통 헬퍼 ───────────

Paint _limb(Color color, double w) => Paint()
  ..color = color
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..style = PaintingStyle.stroke;

Paint _torso(Color color, double w) => Paint()
  ..color = color
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

Paint _fill(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill;

void _joint(Canvas c, Offset p, Color color, double r) {
  c.drawCircle(p, r, _fill(color));
}

void _dumbbell(
  Canvas c,
  Offset center,
  Color color, {
  double length = 0.14,
  double thick = 0.08,
  double barThick = 0.03,
  required Size size,
}) {
  final w = size.width;
  final h = size.height;
  final l = w * length;
  final t = h * thick;
  final bar = h * barThick;
  // 바
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: l * 0.5, height: bar),
      const Radius.circular(2),
    ),
    _fill(color),
  );
  // 양쪽 원판
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - l * 0.3, center.dy),
        width: l * 0.25,
        height: t,
      ),
      const Radius.circular(3),
    ),
    _fill(color),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + l * 0.3, center.dy),
        width: l * 0.25,
        height: t,
      ),
      const Radius.circular(3),
    ),
    _fill(color),
  );
}

// ─────────── 푸시업 (플랭크 하강 자세) ───────────
class _PushupPainter extends CustomPainter {
  final Color color;
  _PushupPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final limbW = w * 0.065;
    final torsoW = w * 0.11;
    final jointR = w * 0.035;
    final groundY = h * 0.88;

    // 바닥 그림자
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, groundY + h * 0.03),
          width: w * 0.8,
          height: h * 0.03),
      _fill(color.withValues(alpha: 0.15)),
    );

    // 좌표 — 플랭크 자세, 손과 발 모두 바닥에 닿음
    final head = Offset(w * 0.14, h * 0.48);
    final shoulder = Offset(w * 0.28, h * 0.52);
    final hip = Offset(w * 0.66, h * 0.60);
    final knee = Offset(w * 0.82, h * 0.72);
    final foot = Offset(w * 0.95, groundY);

    // 손은 바닥, 팔꿈치 살짝 굽힘
    final handFront = Offset(w * 0.28, groundY);
    final elbowFront = Offset(w * 0.26, h * 0.72);
    final handBack = Offset(w * 0.36, groundY);
    final elbowBack = Offset(w * 0.34, h * 0.72);

    // 뒤쪽 팔 (반투명)
    canvas.drawLine(
      shoulder.translate(w * 0.06, 0),
      elbowBack,
      _limb(color.withValues(alpha: 0.5), limbW * 0.85),
    );
    canvas.drawLine(
      elbowBack,
      handBack,
      _limb(color.withValues(alpha: 0.5), limbW * 0.85),
    );

    // 몸통
    canvas.drawLine(shoulder, hip, _torso(color, torsoW));

    // 다리 (발이 바닥에 닿음)
    canvas.drawLine(hip, knee, _limb(color, limbW));
    canvas.drawLine(knee, foot, _limb(color, limbW));

    // 발 디테일 (바닥에 평평하게)
    canvas.drawLine(
      foot,
      Offset(foot.dx - w * 0.05, groundY),
      _limb(color, limbW),
    );

    // 앞쪽 팔 (굽힘)
    canvas.drawLine(shoulder, elbowFront, _limb(color, limbW));
    canvas.drawLine(elbowFront, handFront, _limb(color, limbW));

    // 머리
    canvas.drawCircle(head, w * 0.085, _fill(color));

    // 관절 점
    _joint(canvas, shoulder, color, jointR);
    _joint(canvas, elbowFront, color, jointR * 0.85);
    _joint(canvas, hip, color, jointR);
    _joint(canvas, knee, color, jointR * 0.85);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────── 이두컬 (왼팔 굽힘, 덤벨 어깨 앞) ───────────
class _CurlPainter extends CustomPainter {
  final Color color;
  _CurlPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final limbW = w * 0.065;
    final torsoW = w * 0.11;
    final jointR = w * 0.035;

    // 바닥 그림자
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.94),
          width: w * 0.36,
          height: h * 0.04),
      _fill(color.withValues(alpha: 0.15)),
    );

    // 기준 좌표
    final head = Offset(w * 0.50, h * 0.16);
    final neck = Offset(w * 0.50, h * 0.26);
    final shoulderL = Offset(w * 0.42, h * 0.30);
    final shoulderR = Offset(w * 0.58, h * 0.30);
    final hip = Offset(w * 0.50, h * 0.60);
    final hipL = Offset(w * 0.44, h * 0.62);
    final hipR = Offset(w * 0.56, h * 0.62);
    final kneeL = Offset(w * 0.42, h * 0.78);
    final kneeR = Offset(w * 0.58, h * 0.78);
    final footL = Offset(w * 0.40, h * 0.92);
    final footR = Offset(w * 0.60, h * 0.92);

    // 왼팔 (굽혀서 덤벨 들어올림) — 팔꿈치/손을 몸에서 확실히 띄움
    final elbowL = Offset(w * 0.22, h * 0.50);
    final handL = Offset(w * 0.24, h * 0.28);
    canvas.drawLine(shoulderL, elbowL, _limb(color, limbW));
    canvas.drawLine(elbowL, handL, _limb(color, limbW));

    // 오른팔 (자연스럽게 내림) — 몸에서 띄움
    final elbowR = Offset(w * 0.72, h * 0.48);
    final handR = Offset(w * 0.78, h * 0.62);
    canvas.drawLine(shoulderR, elbowR, _limb(color, limbW));
    canvas.drawLine(elbowR, handR, _limb(color, limbW));

    // 몸통
    canvas.drawLine(neck, hip, _torso(color, torsoW));

    // 다리
    canvas.drawLine(hipL, kneeL, _limb(color, limbW));
    canvas.drawLine(kneeL, footL, _limb(color, limbW));
    canvas.drawLine(hipR, kneeR, _limb(color, limbW));
    canvas.drawLine(kneeR, footR, _limb(color, limbW));

    // 발 디테일
    canvas.drawLine(
      footL,
      Offset(footL.dx - w * 0.04, footL.dy),
      _limb(color, limbW),
    );
    canvas.drawLine(
      footR,
      Offset(footR.dx + w * 0.04, footR.dy),
      _limb(color, limbW),
    );

    // 머리
    canvas.drawCircle(head, w * 0.085, _fill(color));

    // 덤벨 (왼손 위)
    _dumbbell(canvas, handL.translate(0, -h * 0.02), color, size: size);

    // 오른손 쥔 덤벨 (작게)
    _dumbbell(canvas, handR.translate(0, h * 0.01), color,
        length: 0.10, thick: 0.06, size: size);

    // 관절
    _joint(canvas, shoulderL, color, jointR);
    _joint(canvas, shoulderR, color, jointR);
    _joint(canvas, elbowL, color, jointR * 0.85);
    _joint(canvas, elbowR, color, jointR * 0.85);
    _joint(canvas, hip, color, jointR);
    _joint(canvas, kneeL, color, jointR * 0.85);
    _joint(canvas, kneeR, color, jointR * 0.85);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────── 사이드 레터럴 레이즈 (양팔 수평) ───────────
class _LateralRaisePainter extends CustomPainter {
  final Color color;
  _LateralRaisePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final limbW = w * 0.065;
    final torsoW = w * 0.11;
    final jointR = w * 0.035;

    // 바닥 그림자
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.94),
          width: w * 0.42,
          height: h * 0.04),
      _fill(color.withValues(alpha: 0.15)),
    );

    // 좌표
    final head = Offset(w * 0.50, h * 0.22);
    final neck = Offset(w * 0.50, h * 0.32);
    final shoulderL = Offset(w * 0.42, h * 0.36);
    final shoulderR = Offset(w * 0.58, h * 0.36);
    final hip = Offset(w * 0.50, h * 0.62);
    final hipL = Offset(w * 0.44, h * 0.64);
    final hipR = Offset(w * 0.56, h * 0.64);
    final kneeL = Offset(w * 0.42, h * 0.80);
    final kneeR = Offset(w * 0.58, h * 0.80);
    final footL = Offset(w * 0.40, h * 0.92);
    final footR = Offset(w * 0.60, h * 0.92);

    // 양팔 수평 — 어깨 → 팔꿈치(약간 굽힘) → 손
    final elbowL = Offset(w * 0.26, h * 0.38);
    final handL = Offset(w * 0.14, h * 0.40);
    final elbowR = Offset(w * 0.74, h * 0.38);
    final handR = Offset(w * 0.86, h * 0.40);
    canvas.drawLine(shoulderL, elbowL, _limb(color, limbW));
    canvas.drawLine(elbowL, handL, _limb(color, limbW));
    canvas.drawLine(shoulderR, elbowR, _limb(color, limbW));
    canvas.drawLine(elbowR, handR, _limb(color, limbW));

    // 몸통
    canvas.drawLine(neck, hip, _torso(color, torsoW));

    // 다리
    canvas.drawLine(hipL, kneeL, _limb(color, limbW));
    canvas.drawLine(kneeL, footL, _limb(color, limbW));
    canvas.drawLine(hipR, kneeR, _limb(color, limbW));
    canvas.drawLine(kneeR, footR, _limb(color, limbW));

    // 발
    canvas.drawLine(
        footL, Offset(footL.dx - w * 0.04, footL.dy), _limb(color, limbW));
    canvas.drawLine(
        footR, Offset(footR.dx + w * 0.04, footR.dy), _limb(color, limbW));

    // 머리
    canvas.drawCircle(head, w * 0.085, _fill(color));

    // 덤벨 양손
    _dumbbell(canvas, handL, color, size: size);
    _dumbbell(canvas, handR, color, size: size);

    // 관절
    _joint(canvas, shoulderL, color, jointR);
    _joint(canvas, shoulderR, color, jointR);
    _joint(canvas, elbowL, color, jointR * 0.85);
    _joint(canvas, elbowR, color, jointR * 0.85);
    _joint(canvas, hip, color, jointR);
    _joint(canvas, kneeL, color, jointR * 0.85);
    _joint(canvas, kneeR, color, jointR * 0.85);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────── 어깨 재활 (양팔 머리 위로 스트레칭) ───────────
class _ShoulderRehabPainter extends CustomPainter {
  final Color color;
  _ShoulderRehabPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final limbW = w * 0.065;
    final torsoW = w * 0.11;
    final jointR = w * 0.035;

    // 바닥 그림자
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.94),
          width: w * 0.38,
          height: h * 0.04),
      _fill(color.withValues(alpha: 0.15)),
    );

    // 좌표
    final head = Offset(w * 0.50, h * 0.34);
    final neck = Offset(w * 0.50, h * 0.44);
    final shoulderL = Offset(w * 0.42, h * 0.47);
    final shoulderR = Offset(w * 0.58, h * 0.47);
    final hip = Offset(w * 0.50, h * 0.70);
    final hipL = Offset(w * 0.44, h * 0.72);
    final hipR = Offset(w * 0.56, h * 0.72);
    final kneeL = Offset(w * 0.42, h * 0.85);
    final kneeR = Offset(w * 0.58, h * 0.85);
    final footL = Offset(w * 0.40, h * 0.94);
    final footR = Offset(w * 0.60, h * 0.94);

    // 양팔 위로 뻗음 — 어깨 → 팔꿈치 → 손
    final elbowL = Offset(w * 0.32, h * 0.28);
    final handL = Offset(w * 0.24, h * 0.10);
    final elbowR = Offset(w * 0.68, h * 0.28);
    final handR = Offset(w * 0.76, h * 0.10);
    canvas.drawLine(shoulderL, elbowL, _limb(color, limbW));
    canvas.drawLine(elbowL, handL, _limb(color, limbW));
    canvas.drawLine(shoulderR, elbowR, _limb(color, limbW));
    canvas.drawLine(elbowR, handR, _limb(color, limbW));

    // 손가락 힌트 (짧은 선)
    canvas.drawLine(
      handL,
      Offset(handL.dx - w * 0.02, handL.dy - h * 0.03),
      _limb(color, limbW * 0.7),
    );
    canvas.drawLine(
      handR,
      Offset(handR.dx + w * 0.02, handR.dy - h * 0.03),
      _limb(color, limbW * 0.7),
    );

    // 몸통
    canvas.drawLine(neck, hip, _torso(color, torsoW));

    // 다리
    canvas.drawLine(hipL, kneeL, _limb(color, limbW));
    canvas.drawLine(kneeL, footL, _limb(color, limbW));
    canvas.drawLine(hipR, kneeR, _limb(color, limbW));
    canvas.drawLine(kneeR, footR, _limb(color, limbW));

    canvas.drawLine(
        footL, Offset(footL.dx - w * 0.04, footL.dy), _limb(color, limbW));
    canvas.drawLine(
        footR, Offset(footR.dx + w * 0.04, footR.dy), _limb(color, limbW));

    // 머리
    canvas.drawCircle(head, w * 0.085, _fill(color));

    // 관절
    _joint(canvas, shoulderL, color, jointR);
    _joint(canvas, shoulderR, color, jointR);
    _joint(canvas, elbowL, color, jointR * 0.85);
    _joint(canvas, elbowR, color, jointR * 0.85);
    _joint(canvas, hip, color, jointR);
    _joint(canvas, kneeL, color, jointR * 0.85);
    _joint(canvas, kneeR, color, jointR * 0.85);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _DefaultPainter extends CustomPainter {
  final Color color;
  _DefaultPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.25), w * 0.085, _fill(color));
    canvas.drawLine(Offset(w * 0.5, h * 0.34), Offset(w * 0.5, h * 0.7),
        _torso(color, w * 0.11));
    canvas.drawLine(Offset(w * 0.5, h * 0.7), Offset(w * 0.4, h * 0.9),
        _limb(color, w * 0.065));
    canvas.drawLine(Offset(w * 0.5, h * 0.7), Offset(w * 0.6, h * 0.9),
        _limb(color, w * 0.065));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

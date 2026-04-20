import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';

/// Apple Fitness 스타일 링 프로그레스.
///
/// 단일 링 또는 다중 링(중첩) 모두 지원. [rings]에 안쪽→바깥쪽 순으로 전달.
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.rings,
    this.size = 180,
    this.strokeWidth = 14,
    this.gap = 6,
    this.child,
    this.animate = true,
    this.trackColor,
  });

  /// 단일 링 편의 생성자.
  factory ProgressRing.single({
    Key? key,
    required double progress,
    Color color = AppGradients.ringMove,
    double size = 180,
    double strokeWidth = 14,
    Widget? child,
  }) {
    return ProgressRing(
      key: key,
      size: size,
      strokeWidth: strokeWidth,
      rings: [RingData(progress: progress, color: color)],
      child: child,
    );
  }

  final List<RingData> rings;
  final double size;
  final double strokeWidth;
  final double gap;
  final Widget? child;
  final bool animate;
  final Color? trackColor;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.animate) {
      _ctrl.forward();
    } else {
      _ctrl.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant ProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rings != widget.rings) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, _) {
          return CustomPaint(
            painter: _RingPainter(
              rings: widget.rings,
              strokeWidth: widget.strokeWidth,
              gap: widget.gap,
              t: _anim.value,
              trackColor: widget.trackColor ??
                  (isDark
                      ? AppTheme.cardElevatedDark
                      : const Color(0xFFF0F1F5)),
            ),
            child: Center(child: widget.child),
          );
        },
      ),
    );
  }
}

class RingData {
  const RingData({required this.progress, required this.color});

  final double progress; // 0.0 ~ (이상값 허용 — 1.0 넘으면 초과분 표시)
  final Color color;
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.rings,
    required this.strokeWidth,
    required this.gap,
    required this.t,
    required this.trackColor,
  });

  final List<RingData> rings;
  final double strokeWidth;
  final double gap;
  final double t;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // 가장 바깥 반지름부터 안쪽으로 채움
    double outerRadius = (size.shortestSide / 2) - strokeWidth / 2;

    for (int i = rings.length - 1; i >= 0; i--) {
      final ring = rings[i];
      final radius = outerRadius - (rings.length - 1 - i) * (strokeWidth + gap);
      if (radius <= 0) continue;
      final rect = Rect.fromCircle(center: center, radius: radius);

      // 트랙
      final track = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = trackColor;
      canvas.drawCircle(center, radius, track);

      // 진행
      final progress = (ring.progress.clamp(0.0, 1.5)) * t;
      if (progress > 0) {
        final sweep = 2 * math.pi * progress;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: -math.pi / 2 + sweep,
            colors: [
              ring.color.withValues(alpha: 0.85),
              ring.color,
            ],
          ).createShader(rect);
        canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.t != t || old.rings != rings;
}

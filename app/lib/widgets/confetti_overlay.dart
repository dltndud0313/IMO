import 'dart:math';
import 'package:flutter/material.dart';

/// 축하 confetti 오버레이.
/// show()를 호출하면 약 2초간 파티클 애니메이션 표시.
class ConfettiOverlay extends StatefulWidget {
  final VoidCallback? onComplete;
  const ConfettiOverlay({super.key, this.onComplete});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(40, (_) => _Particle(_rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return IgnorePointer(
      child: CustomPaint(
        size: size,
        painter: _ConfettiPainter(
          particles: _particles,
          progress: _ctrl.value,
        ),
      ),
    );
  }
}

class _Particle {
  final double x; // 0~1 시작 x 위치
  final double drift; // 좌우 흔들림
  final double speed; // 낙하 속도 배율
  final Color color;
  final double size;
  final double rotation;

  _Particle(Random rng)
      : x = rng.nextDouble(),
        drift = (rng.nextDouble() - 0.5) * 0.3,
        speed = 0.5 + rng.nextDouble() * 0.8,
        color = _colors[rng.nextInt(_colors.length)],
        size = 4 + rng.nextDouble() * 6,
        rotation = rng.nextDouble() * pi * 2;

  static const _colors = [
    Color(0xFF2962FF),
    Color(0xFFFF5252),
    Color(0xFF00C853),
    Color(0xFFFFAB00),
    Color(0xFF651FFF),
    Color(0xFF00B0FF),
  ];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    for (final p in particles) {
      final x = size.width * p.x + sin(progress * pi * 4 + p.rotation) * 30 * p.drift;
      final y = -20 + size.height * progress * p.speed * 1.2;
      if (y > size.height + 20) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * pi * 3 * p.drift);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}

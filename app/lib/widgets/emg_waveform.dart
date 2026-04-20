import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 실시간 EMG 파형 — 최근 샘플들을 폴리라인으로 그린다.
class EmgWaveform extends StatelessWidget {
  final List<double> samples; // 0~100
  final Color color;
  final double height;
  final String label;
  const EmgWaveform({
    super.key,
    required this.samples,
    this.color = AppTheme.primary,
    this.height = 80,
    this.label = 'EMG',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: _WavePainter(samples: samples, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final List<double> samples;
  final Color color;
  _WavePainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    // 배경 그리드
    final grid = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // 영역 채우기
    final path = Path();
    final fillPath = Path();
    final dx = size.width / (samples.length - 1);
    for (var i = 0; i < samples.length; i++) {
      final x = i * dx;
      final y = size.height - (samples[i] / 100.0).clamp(0.0, 1.0) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()..color = color.withValues(alpha: 0.15),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.samples != samples || old.color != color;
}

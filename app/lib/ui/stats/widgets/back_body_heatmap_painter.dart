import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../models/body_heatmap_region.dart';

class BackBodyHeatmapPainter extends CustomPainter {
  const BackBodyHeatmapPainter({required this.regions});

  final List<BodyHeatmapRegion> regions;

  @override
  void paint(Canvas canvas, Size size) {
    final body = _BodyGuide(size);
    _paintSilhouette(canvas, body);

    _paintRegion(canvas, body.tricepsLeft, _region('left_triceps'));
    _paintRegion(canvas, body.tricepsRight, _region('right_triceps'));
    _paintRegion(
      canvas,
      body.upperTrapeziusLeft,
      _region('left_upper_trapezius'),
    );
    _paintRegion(
      canvas,
      body.upperTrapeziusRight,
      _region('right_upper_trapezius'),
    );
  }

  @override
  bool shouldRepaint(covariant BackBodyHeatmapPainter oldDelegate) {
    return oldDelegate.regions != regions;
  }

  BodyHeatmapRegion? _region(String key) {
    for (final region in regions) {
      if (region.key == key && !region.isPostureIndicator) {
        return region;
      }
    }
    return null;
  }
}

void _paintSilhouette(Canvas canvas, _BodyGuide body) {
  final paint = Paint()
    ..color = AppColors.heatmapInactive.withValues(alpha: 0.18)
    ..style = PaintingStyle.fill;
  final outline = Paint()
    ..color = AppColors.heatmapInactive.withValues(alpha: 0.42)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  canvas.drawRRect(body.head, paint);
  canvas.drawRRect(body.neck, paint);
  canvas.drawRRect(body.torso, paint);
  canvas.drawRRect(body.leftUpperArm, paint);
  canvas.drawRRect(body.rightUpperArm, paint);
  canvas.drawRRect(body.leftLowerArm, paint);
  canvas.drawRRect(body.rightLowerArm, paint);
  canvas.drawRRect(body.leftLeg, paint);
  canvas.drawRRect(body.rightLeg, paint);

  canvas.drawRRect(body.head, outline);
  canvas.drawRRect(body.torso, outline);
  canvas.drawRRect(body.leftUpperArm, outline);
  canvas.drawRRect(body.rightUpperArm, outline);
  canvas.drawRRect(body.leftLowerArm, outline);
  canvas.drawRRect(body.rightLowerArm, outline);
  canvas.drawRRect(body.leftLeg, outline);
  canvas.drawRRect(body.rightLeg, outline);
}

void _paintRegion(Canvas canvas, RRect shape, BodyHeatmapRegion? region) {
  final paint = Paint()
    ..color = _heatmapColorForPercent(region?.percent)
    ..style = PaintingStyle.fill;
  final border = Paint()
    ..color = AppColors.card.withValues(alpha: 0.58)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  canvas.drawRRect(shape, paint);
  canvas.drawRRect(shape, border);
}

Color _heatmapColorForPercent(double? percent) {
  if (percent == null) {
    return AppColors.heatmapInactive;
  }

  final value = percent.clamp(0.0, 100.0);
  if (value < 20) return AppColors.heatmapLow.withValues(alpha: 0.55);
  if (value < 40) return AppColors.heatmapLow;
  if (value < 60) return AppColors.heatmapNormal;
  if (value < 80) return AppColors.heatmapHigh;
  return AppColors.heatmapDanger;
}

class _BodyGuide {
  _BodyGuide(Size size)
    : centerX = size.width / 2,
      top = size.height * 0.05,
      scale = size.shortestSide / 390;

  final double centerX;
  final double top;
  final double scale;

  RRect get head => RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(centerX, top + 32 * scale),
      width: 48 * scale,
      height: 56 * scale,
    ),
    Radius.circular(24 * scale),
  );

  RRect get neck => _rounded(
    centerX - 16 * scale,
    top + 62 * scale,
    32 * scale,
    24 * scale,
    10 * scale,
  );

  RRect get torso => _rounded(
    centerX - 72 * scale,
    top + 82 * scale,
    144 * scale,
    170 * scale,
    42 * scale,
  );

  RRect get leftUpperArm => _rounded(
    centerX - 126 * scale,
    top + 92 * scale,
    42 * scale,
    108 * scale,
    22 * scale,
  );

  RRect get rightUpperArm => _rounded(
    centerX + 84 * scale,
    top + 92 * scale,
    42 * scale,
    108 * scale,
    22 * scale,
  );

  RRect get leftLowerArm => _rounded(
    centerX - 144 * scale,
    top + 190 * scale,
    34 * scale,
    116 * scale,
    18 * scale,
  );

  RRect get rightLowerArm => _rounded(
    centerX + 110 * scale,
    top + 190 * scale,
    34 * scale,
    116 * scale,
    18 * scale,
  );

  RRect get leftLeg => _rounded(
    centerX - 58 * scale,
    top + 244 * scale,
    46 * scale,
    126 * scale,
    22 * scale,
  );

  RRect get rightLeg => _rounded(
    centerX + 12 * scale,
    top + 244 * scale,
    46 * scale,
    126 * scale,
    22 * scale,
  );

  RRect get tricepsLeft => _rounded(
    centerX - 121 * scale,
    top + 128 * scale,
    30 * scale,
    66 * scale,
    15 * scale,
  );

  RRect get tricepsRight => _rounded(
    centerX + 91 * scale,
    top + 128 * scale,
    30 * scale,
    66 * scale,
    15 * scale,
  );

  RRect get upperTrapeziusLeft => _rounded(
    centerX - 58 * scale,
    top + 88 * scale,
    52 * scale,
    46 * scale,
    16 * scale,
  );

  RRect get upperTrapeziusRight => _rounded(
    centerX + 6 * scale,
    top + 88 * scale,
    52 * scale,
    46 * scale,
    16 * scale,
  );

  RRect _rounded(
    double left,
    double top,
    double width,
    double height,
    double radius,
  ) {
    return RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      Radius.circular(radius),
    );
  }
}

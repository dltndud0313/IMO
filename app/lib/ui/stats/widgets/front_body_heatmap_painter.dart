import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../models/body_heatmap_region.dart';

class FrontBodyHeatmapPainter extends CustomPainter {
  const FrontBodyHeatmapPainter({required this.regions});

  final List<BodyHeatmapRegion> regions;

  @override
  void paint(Canvas canvas, Size size) {
    final body = _BodyGuide(size);
    _paintSilhouette(canvas, body);

    _paintRegion(canvas, body.chestLeft, _region('left_chest'));
    _paintRegion(canvas, body.chestRight, _region('right_chest'));
    _paintRegion(canvas, body.bicepsLeft, _region('left_biceps'));
    _paintRegion(canvas, body.bicepsRight, _region('right_biceps'));
    _paintRegion(canvas, body.forearmLeft, _region('left_forearm'));
    _paintRegion(canvas, body.forearmRight, _region('right_forearm'));
    _paintRegion(
      canvas,
      body.lateralDeltoidLeft,
      _region('left_lateral_deltoid'),
    );
    _paintRegion(
      canvas,
      body.lateralDeltoidRight,
      _region('right_lateral_deltoid'),
    );
  }

  @override
  bool shouldRepaint(covariant FrontBodyHeatmapPainter oldDelegate) {
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

  RRect get chestLeft => _rounded(
    centerX - 56 * scale,
    top + 105 * scale,
    52 * scale,
    58 * scale,
    16 * scale,
  );

  RRect get chestRight => _rounded(
    centerX + 4 * scale,
    top + 105 * scale,
    52 * scale,
    58 * scale,
    16 * scale,
  );

  RRect get bicepsLeft => _rounded(
    centerX - 121 * scale,
    top + 126 * scale,
    30 * scale,
    58 * scale,
    15 * scale,
  );

  RRect get bicepsRight => _rounded(
    centerX + 91 * scale,
    top + 126 * scale,
    30 * scale,
    58 * scale,
    15 * scale,
  );

  RRect get forearmLeft => _rounded(
    centerX - 139 * scale,
    top + 214 * scale,
    24 * scale,
    70 * scale,
    12 * scale,
  );

  RRect get forearmRight => _rounded(
    centerX + 115 * scale,
    top + 214 * scale,
    24 * scale,
    70 * scale,
    12 * scale,
  );

  RRect get lateralDeltoidLeft => _rounded(
    centerX - 96 * scale,
    top + 94 * scale,
    34 * scale,
    42 * scale,
    18 * scale,
  );

  RRect get lateralDeltoidRight => _rounded(
    centerX + 62 * scale,
    top + 94 * scale,
    34 * scale,
    42 * scale,
    18 * scale,
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

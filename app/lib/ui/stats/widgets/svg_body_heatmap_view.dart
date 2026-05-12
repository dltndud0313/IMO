import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/themes/app_colors.dart';
import '../models/body_heatmap_region.dart';

enum BodyGender { male, female }

BodyGender bodyGenderFromCode(String code) {
  return switch (code.toUpperCase()) {
    'FEMALE' => BodyGender.female,
    _ => BodyGender.male, // MALE / OTHER / 빈값 → male default
  };
}

class SvgBodyHeatmapView extends StatelessWidget {
  const SvgBodyHeatmapView({
    super.key,
    required this.regions,
    this.selectedSide = BodyHeatmapViewSide.front,
    this.gender = BodyGender.male,
    this.height = 390,
  });

  final List<BodyHeatmapRegion> regions;
  final BodyHeatmapViewSide selectedSide;
  final BodyGender gender;
  final double height;

  @override
  Widget build(BuildContext context) {
    final intensities = <String, double>{
      for (final r in regions)
        if (!r.isPostureIndicator && r.hasData) r.key: r.percent!,
    };
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Center(
        child: SvgPicture.asset(
          SvgBodyHeatmapView.assetPathFor(
            gender,
            selectedSide == BodyHeatmapViewSide.back,
          ),
          height: height,
          colorMapper: _MuscleColorMapper(intensities),
        ),
      ),
    );
  }

  static String assetPathFor(BodyGender gender, bool isBack) {
    final g = gender == BodyGender.female ? 'female' : 'male';
    final s = isBack ? 'back' : 'front';
    return 'assets/svg/${g}_${s}_body.svg';
  }
}

class _MuscleColorMapper extends ColorMapper {
  const _MuscleColorMapper(this.intensities);

  final Map<String, double> intensities; // key → 0.0~100.0

  // activation이 측정됐지만 0인 경우 — no data(neutral)와 구분
  static const _zeroActivationColor = Color(0xFFD1D5DB);

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (attributeName != 'fill') return color;
    if (id == null) return color;

    final percent = intensities[id];
    if (percent == null) return color; // no data → SVG 원본 색(neutral gray) 유지
    if (percent == 0.0) return _zeroActivationColor;

    return _colorForPercent(percent);
  }

  static Color _colorForPercent(double percent) {
    final v = percent.clamp(0.0, 100.0);
    if (v < 20) return AppColors.heatmapLow.withValues(alpha: 0.55);
    if (v < 40) return AppColors.heatmapLow;
    if (v < 60) return AppColors.heatmapNormal;
    if (v < 80) return AppColors.heatmapHigh;
    return AppColors.heatmapDanger;
  }
}

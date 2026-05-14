import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/themes/design_tokens.dart';
import '../../stats/widgets/svg_body_heatmap_view.dart' show BodyGender;
import 'exercise_target_regions.dart';

/// 자세 가이드 화면용 타겟 근육 강조 SVG 바디 뷰.
///
/// - 운동의 타겟 근육 (primary/supporting) 만 색으로 강조
/// - 후면 타겟이 있는 운동 (푸시업·사이드 레터럴) 은 전면+후면 나란히 표시
/// - 후면 타겟 없는 운동 (이두컬) 은 전면만 크게 표시
/// - 운동별 미세 조정된 crop 으로 상체 zoom-in
class ExerciseGuideBodyView extends StatelessWidget {
  const ExerciseGuideBodyView({
    super.key,
    required this.exerciseId,
    this.gender = BodyGender.male,
    this.height = 320,
  });

  final String exerciseId;
  final BodyGender gender;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = findExerciseTargetMap(exerciseId);

    // 매핑 없는 운동 → 기본 인체 아이콘 fallback
    if (target == null) {
      return SizedBox(
        height: height,
        child: Center(
          child: Icon(
            Icons.accessibility_new_rounded,
            size: 100,
            color: AppColors.textTertiary,
          ),
        ),
      );
    }

    final intensities = target.toIntensityMap();
    final crop = findExerciseBodyCrop(exerciseId);
    final showBack = target.hasBackTargets;

    if (!showBack) {
      // 전면만 크게
      return SizedBox(
        height: height,
        child: _CroppedBodySvg(
          assetPath: _assetPathFor(gender, isBack: false),
          intensities: intensities,
          crop: crop,
        ),
      );
    }

    // 전면 + 후면 나란히 (50:50)
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: _LabeledBodySvg(
              label: '전면',
              assetPath: _assetPathFor(gender, isBack: false),
              intensities: intensities,
              crop: crop,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _LabeledBodySvg(
              label: '후면',
              assetPath: _assetPathFor(gender, isBack: true),
              intensities: intensities,
              crop: crop,
            ),
          ),
        ],
      ),
    );
  }

  static String _assetPathFor(BodyGender gender, {required bool isBack}) {
    final g = gender == BodyGender.female ? 'female' : 'male';
    final s = isBack ? 'back' : 'front';
    return 'assets/svg/${g}_${s}_body.svg';
  }
}

class _LabeledBodySvg extends StatelessWidget {
  const _LabeledBodySvg({
    required this.label,
    required this.assetPath,
    required this.intensities,
    required this.crop,
  });

  final String label;
  final String assetPath;
  final Map<String, double> intensities;
  final BodyCropConfig crop;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _CroppedBodySvg(
            assetPath: assetPath,
            intensities: intensities,
            crop: crop,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class _CroppedBodySvg extends StatelessWidget {
  const _CroppedBodySvg({
    required this.assetPath,
    required this.intensities,
    required this.crop,
  });

  final String assetPath;
  final Map<String, double> intensities;
  final BodyCropConfig crop;

  // 원본 SVG viewBox 비율 (724 / 1450).
  // height 기준으로 width 계산 시 사용.
  static const _svgAspectRatio = 724.0 / 1450.0;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 줌 배율 만큼 SVG 자체 크기를 키우고, OverflowBox 로 부모를 넘어가게.
          // 부모는 ClipRect 라 잘라서 보여줌. alignment 로 어떤 부분을 보여줄지 결정.
          final svgHeight = constraints.maxHeight * crop.zoom;
          final svgWidth = svgHeight * _svgAspectRatio;
          return OverflowBox(
            alignment: crop.alignment,
            minWidth: svgWidth,
            maxWidth: svgWidth,
            minHeight: svgHeight,
            maxHeight: svgHeight,
            child: SvgPicture.asset(
              assetPath,
              colorMapper: _GuideMuscleColorMapper(intensities),
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}

/// 자세 가이드 전용 ColorMapper.
///
/// primary (≥70%) → 빨강 (danger 색)
/// supporting (40~70%) → 주황 (high 색)
/// 그 외 → 원본 색 유지 (회색 중립)
class _GuideMuscleColorMapper extends ColorMapper {
  const _GuideMuscleColorMapper(this.intensities);

  final Map<String, double> intensities;

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
    if (percent == null) return color;
    if (percent >= 70) {
      return AppColors.heatmapDanger.withValues(alpha: 0.85);
    }
    if (percent >= 40) {
      return AppColors.heatmapHigh.withValues(alpha: 0.75);
    }
    return color;
  }
}

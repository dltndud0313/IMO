import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/themes/design_tokens.dart';
import '../../stats/widgets/svg_body_heatmap_view.dart' show BodyGender;
import 'cropped_body_svg.dart';
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

    final mapper = _GuideMuscleColorMapper(intensities);

    if (!showBack) {
      // 전면만 크게
      return SizedBox(
        height: height,
        child: CroppedBodySvg(
          assetPath: bodySvgAssetPath(gender, isBack: false),
          crop: crop,
          colorMapper: mapper,
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
              assetPath: bodySvgAssetPath(gender, isBack: false),
              crop: crop,
              colorMapper: mapper,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _LabeledBodySvg(
              label: '후면',
              assetPath: bodySvgAssetPath(gender, isBack: true),
              crop: crop,
              colorMapper: mapper,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledBodySvg extends StatelessWidget {
  const _LabeledBodySvg({
    required this.label,
    required this.assetPath,
    required this.crop,
    required this.colorMapper,
  });

  final String label;
  final String assetPath;
  final BodyCropConfig crop;
  final ColorMapper colorMapper;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CroppedBodySvg(
            assetPath: assetPath,
            crop: crop,
            colorMapper: colorMapper,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: AppTextStyles.caption),
      ],
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

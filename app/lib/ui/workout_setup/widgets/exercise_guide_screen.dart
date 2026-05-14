import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import 'exercise_catalog_data.dart';
import 'exercise_guide_body_view.dart';

class ExerciseGuideScreen extends StatelessWidget {
  const ExerciseGuideScreen({
    super.key,
    this.exerciseId = 'pushup',
    this.categoryId,
  });

  final String exerciseId;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    final guide = _exerciseGuides[exerciseId] ?? _exerciseGuides['pushup']!;

    return AppScaffold(
      title: '자세 가이드',
      showBackButton: true,
      onBack: () {
        final resolvedCategoryId =
            categoryId ?? categoryIdForExercise(exerciseId);
        context.go('/workout-exercises?category=$resolvedCategoryId');
      },
      scrollable: true,
      bottom: ImoButton(
        label: '다음',
        onPressed: () => context.go('/workout-plan?exercise=$exerciseId'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TargetAreaCard(guide: guide, exerciseId: exerciseId),
          const SizedBox(height: AppSpacing.sectionGap),
          _GuideStepCard(steps: guide.steps),
          const SizedBox(height: AppSpacing.md),
          _GuideCautionCard(cautions: guide.cautions),
        ],
      ),
    );
  }
}

class _TargetAreaCard extends StatelessWidget {
  const _TargetAreaCard({required this.guide, required this.exerciseId});

  final _ExerciseGuide guide;
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: guide.gradient),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.card,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(guide.title, style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(guide.description, style: AppTextStyles.bodyLg),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.cardSubtle,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.track_changes_rounded,
                      size: 18,
                      color: AppColors.primaryStrong,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('타겟 부위', style: AppTextStyles.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ExerciseGuideBodyView(
                  exerciseId: exerciseId,
                  height: 300,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              guide.targets.join(' · '),
              style: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStepCard extends StatelessWidget {
  const _GuideStepCard({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rounded,
                size: 18,
                color: AppColors.primaryStrong,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('자세 가이드', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < steps.length; index++) ...[
            _GuideStepItem(index: index + 1, text: steps[index]),
            if (index != steps.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _GuideStepItem extends StatelessWidget {
  const _GuideStepItem({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primaryStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTextStyles.bodyLg)),
      ],
    );
  }
}

class _GuideCautionCard extends StatelessWidget {
  const _GuideCautionCard({required this.cautions});

  final List<String> cautions;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '주의사항',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: const Color(0xFFB97509),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final caution in cautions) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.circle, size: 5, color: AppColors.warning),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(caution, style: AppTextStyles.body)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _ExerciseGuide {
  const _ExerciseGuide({
    required this.title,
    required this.description,
    required this.targets,
    required this.steps,
    required this.cautions,
    required this.markers,
    required this.gradient,
  });

  final String title;
  final String description;
  final List<String> targets;
  final List<String> steps;
  final List<String> cautions;
  final List<_TargetMarkerData> markers;
  final List<Color> gradient;
}

class _TargetMarkerData {
  const _TargetMarkerData({
    required this.label,
    required this.top,
    this.left,
    this.right,
  });

  final String label;
  final double top;
  final double? left;
  final double? right;
}

const _exerciseGuides = {
  'pushup': _ExerciseGuide(
    title: '푸시업',
    description: '상체 전반을 강화하는 기본 운동',
    targets: ['가슴', '삼두근', '어깨'],
    steps: [
      '어깨 너비로 손을 벌려 바닥에 댑니다',
      '몸을 일직선으로 유지합니다',
      '팔꿈치를 구부려 가슴이 바닥에 가까워질 때까지 내려갑니다',
      '팔을 펴며 시작 자세로 돌아옵니다',
    ],
    cautions: [
      '허리가 꺾이지 않도록 복부에 힘을 주세요.',
      '어깨가 귀 쪽으로 올라가지 않게 유지하세요.',
      '통증이 있으면 즉시 중단하고 자세를 확인하세요.',
    ],
    markers: [
      _TargetMarkerData(label: '대흉근', top: 104, left: 90),
      _TargetMarkerData(label: '삼두근', top: 142, right: 46),
      _TargetMarkerData(label: '전면 삼각근', top: 194, left: 58),
    ],
    gradient: [AppColors.primary, AppColors.primaryStrong],
  ),
  'lateral_raise': _ExerciseGuide(
    title: '싸레레',
    description: '측면 어깨 자극을 위한 운동',
    targets: ['측면 삼각근', '승모근 보조'],
    steps: [
      '덤벨을 양손에 들고 몸 옆에 둡니다',
      '팔꿈치를 살짝 굽힌 상태를 유지합니다',
      '어깨 높이까지 양팔을 천천히 들어 올립니다',
      '반동 없이 천천히 시작 자세로 돌아옵니다',
    ],
    cautions: [
      '어깨가 과하게 올라가지 않도록 주의하세요.',
      '허리를 젖히지 않고 몸통을 고정하세요.',
      '너무 무거운 중량보다 정확한 자세가 중요합니다.',
    ],
    markers: [
      _TargetMarkerData(label: '측면 삼각근', top: 96, right: 56),
      _TargetMarkerData(label: '승모근', top: 70, left: 96),
    ],
    gradient: [AppColors.secondary, Color(0xFF5DC447)],
  ),
  'bicep_curl': _ExerciseGuide(
    title: '이두컬',
    description: '이두근 수축을 집중적으로 보는 운동',
    targets: ['이두근', '전완근'],
    steps: [
      '덤벨을 양손에 들고 팔을 아래로 둡니다',
      '팔꿈치를 몸 옆에 고정합니다',
      '손바닥이 위를 향하도록 들어 올립니다',
      '천천히 내려오며 이두근 긴장을 유지합니다',
    ],
    cautions: [
      '상체를 뒤로 젖히며 반동을 쓰지 마세요.',
      '팔꿈치 위치가 크게 움직이지 않도록 하세요.',
      '손목이 꺾이지 않게 중립을 유지하세요.',
    ],
    markers: [
      _TargetMarkerData(label: '이두근', top: 118, left: 58),
      _TargetMarkerData(label: '전완근', top: 162, left: 54),
    ],
    gradient: [Color(0xFFFFB371), AppColors.warning],
  ),
};

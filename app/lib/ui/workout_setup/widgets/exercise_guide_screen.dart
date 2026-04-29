import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class ExerciseGuideScreen extends StatelessWidget {
  const ExerciseGuideScreen({
    super.key,
    this.exerciseId = 'pushup',
  });

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final guide = _exerciseGuides[exerciseId] ?? _exerciseGuides['pushup']!;

    return AppScaffold(
      title: guide.title,
      subtitle: '운동 안내',
      showBackButton: true,
      scrollable: true,
      bottom: ImoButton(
        label: '운동 계획 설정',
        rightIcon: const Icon(Icons.arrow_forward_rounded),
        onPressed: () => context.go('/workout-plan?exercise=$exerciseId'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuideHeroCard(guide: guide),
          const SizedBox(height: AppSpacing.sectionGap),
          _GuideStepCard(steps: guide.steps),
          const SizedBox(height: AppSpacing.md),
          _GuideCautionCard(cautions: guide.cautions),
        ],
      ),
    );
  }
}

class _GuideHeroCard extends StatelessWidget {
  const _GuideHeroCard({required this.guide});

  final _ExerciseGuide guide;

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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: guide.gradient,
                  ),
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
                    Text(guide.title, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      guide.description,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ImoCard(
            variant: ImoCardVariant.subtle,
            paddingSize: ImoCardPadding.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.track_changes_rounded,
                      size: 16,
                      color: AppColors.primaryStrong,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('주요 근육', style: AppTextStyles.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final target in guide.targets)
                      ImoChip(
                        label: target,
                        variant: ImoChipVariant.selected,
                        icon: const Icon(Icons.circle, size: 8),
                      ),
                  ],
                ),
              ],
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
              Text('운동 방법', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < steps.length; index++) ...[
            _GuideStepItem(index: index + 1, text: steps[index]),
            if (index != steps.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _GuideStepItem extends StatelessWidget {
  const _GuideStepItem({
    required this.index,
    required this.text,
  });

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
        Expanded(
          child: Text(text, style: AppTextStyles.body),
        ),
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
                '시작 전 확인',
                style: AppTextStyles.label.copyWith(color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final caution in cautions) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(caution, style: AppTextStyles.bodySmall)),
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
    required this.gradient,
  });

  final String title;
  final String description;
  final List<String> targets;
  final List<String> steps;
  final List<String> cautions;
  final List<Color> gradient;
}

const _exerciseGuides = {
  'pushup': _ExerciseGuide(
    title: '푸시업',
    description: '상체 근활성도와 자세 안정성을 확인하는 운동입니다.',
    targets: ['가슴', '어깨', '삼두'],
    steps: [
      '양손을 어깨보다 조금 넓게 짚습니다.',
      '어깨부터 발목까지 몸의 라인을 곧게 유지합니다.',
      '팔꿈치가 흔들리지 않도록 천천히 몸을 낮춥니다.',
      '바닥을 밀어내며 시작 자세로 돌아옵니다.',
    ],
    cautions: [
      '허리가 아래로 꺼지지 않게 주의합니다.',
      '캘리브레이션과 측정 중에는 동작을 서두르지 않습니다.',
      '통증이나 어지러움이 있으면 즉시 중단합니다.',
    ],
    gradient: [AppColors.primary, AppColors.primaryStrong],
  ),
  'lateral_raise': _ExerciseGuide(
    title: '사이드 레터럴 레이즈',
    description: '측면 어깨 활성도와 보상 움직임을 확인하는 운동입니다.',
    targets: ['측면 삼각근', '상부 승모근'],
    steps: [
      '상체를 곧게 세우고 어깨 힘을 뺍니다.',
      '양팔을 옆으로 천천히 들어 올립니다.',
      '어깨가 으쓱 올라가지 않도록 어깨 높이 근처에서 멈춥니다.',
      '팔을 천천히 내리며 1회를 마무리합니다.',
    ],
    cautions: [
      '어깨가 귀 쪽으로 올라가지 않게 합니다.',
      '손목과 팔꿈치 라인을 안정적으로 유지합니다.',
      '센서 반응을 확인할 때는 가벼운 부하로 진행합니다.',
    ],
    gradient: [AppColors.secondary, Color(0xFF5DC447)],
  ),
  'bicep_curl': _ExerciseGuide(
    title: '바이셉 컬',
    description: '팔꿈치 굽힘 동작의 일관성을 확인하는 운동입니다.',
    targets: ['이두', '전완'],
    steps: [
      '상체를 곧게 세우고 팔꿈치를 몸 가까이에 둡니다.',
      '몸통을 흔들지 않고 팔을 위로 굽힙니다.',
      '가장 높은 지점에서 잠시 멈춥니다.',
      '긴장을 유지하며 팔을 천천히 내립니다.',
    ],
    cautions: [
      '허리나 어깨 반동을 쓰지 않습니다.',
      '팔꿈치 위치를 안정적으로 유지합니다.',
      '센서나 밴드가 느슨하면 중단하고 다시 고정합니다.',
    ],
    gradient: [Color(0xFFFFB371), AppColors.warning],
  ),
};

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
      subtitle: 'Exercise guide',
      showBackButton: true,
      scrollable: true,
      bottom: ImoButton(
        label: 'Set workout plan',
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
                    Text('Target muscles', style: AppTextStyles.label),
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
              Text('How to move', style: AppTextStyles.label),
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
                'Check before starting',
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
    title: 'Push-up',
    description: 'A compound movement for checking upper-body activation.',
    targets: ['Chest', 'Shoulder', 'Triceps'],
    steps: [
      'Place both hands slightly wider than shoulder width.',
      'Keep the body line stable from shoulder to ankle.',
      'Lower the body slowly while keeping the elbows controlled.',
      'Push the floor away and return to the starting position.',
    ],
    cautions: [
      'Avoid letting the lower back collapse.',
      'Do not rush the movement during calibration or measurement.',
      'Stop immediately if pain or dizziness occurs.',
    ],
    gradient: [AppColors.primary, AppColors.primaryStrong],
  ),
  'lateral_raise': _ExerciseGuide(
    title: 'Lateral raise',
    description: 'A shoulder movement for checking side deltoid activation.',
    targets: ['Side deltoid', 'Upper trapezius'],
    steps: [
      'Stand upright and keep the shoulders relaxed.',
      'Raise both arms to the side with controlled speed.',
      'Stop near shoulder height without shrugging.',
      'Lower the arms slowly to complete one repetition.',
    ],
    cautions: [
      'Avoid lifting the shoulders toward the ears.',
      'Keep the wrist and elbow line stable.',
      'Use a light load while checking sensor response.',
    ],
    gradient: [AppColors.secondary, Color(0xFF5DC447)],
  ),
  'bicep_curl': _ExerciseGuide(
    title: 'Bicep curl',
    description: 'An arm movement for checking elbow flexion consistency.',
    targets: ['Biceps', 'Forearm'],
    steps: [
      'Stand upright and keep the elbows close to the body.',
      'Curl the arms upward without swinging the torso.',
      'Pause briefly at the top position.',
      'Lower the arms slowly and keep tension controlled.',
    ],
    cautions: [
      'Avoid using momentum from the back or shoulder.',
      'Keep the elbow position stable.',
      'Stop if the sensor or band feels loose.',
    ],
    gradient: [Color(0xFFFFB371), AppColors.warning],
  ),
};

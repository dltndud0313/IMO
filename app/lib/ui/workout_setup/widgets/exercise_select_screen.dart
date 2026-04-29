import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class ExerciseSelectScreen extends StatelessWidget {
  const ExerciseSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Workout Setup',
      showBackButton: true,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ExerciseSelectIntro(),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('Exercise', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          for (final exercise in _exerciseOptions) ...[
            _ExerciseOptionCard(
              option: exercise,
              onTap: () => context.go('/workout-guide?exercise=${exercise.id}'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _ExerciseSelectIntro extends StatelessWidget {
  const _ExerciseSelectIntro();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
          child: const Icon(
            Icons.fitness_center_rounded,
            color: AppColors.primaryStrong,
            size: 20,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your movement', style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Select an exercise before sending the workout plan to Pi.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseOptionCard extends StatelessWidget {
  const _ExerciseOptionCard({
    required this.option,
    required this.onTap,
  });

  final _ExerciseOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      interactive: true,
      onTap: onTap,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: option.gradient,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Icon(option.icon, color: AppColors.card, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        option.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ImoChip(
                      label: option.level,
                      variant: ImoChipVariant.selected,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  option.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.textTertiary,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _ExerciseOption {
  const _ExerciseOption({
    required this.title,
    required this.id,
    required this.description,
    required this.level,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String id;
  final String description;
  final String level;
  final IconData icon;
  final List<Color> gradient;
}

const _exerciseOptions = [
  _ExerciseOption(
    id: 'pushup',
    title: 'Push-up',
    description: 'Track chest, shoulder, and triceps activation.',
    level: 'Basic',
    icon: Icons.fitness_center_rounded,
    gradient: [AppColors.primary, AppColors.primaryStrong],
  ),
  _ExerciseOption(
    id: 'lateral_raise',
    title: 'Lateral raise',
    description: 'Check shoulder activation and compensation patterns.',
    level: 'Basic',
    icon: Icons.accessibility_new_rounded,
    gradient: [AppColors.secondary, Color(0xFF5DC447)],
  ),
  _ExerciseOption(
    id: 'bicep_curl',
    title: 'Bicep curl',
    description: 'Review arm activation and movement consistency.',
    level: 'Basic',
    icon: Icons.sports_gymnastics_rounded,
    gradient: [Color(0xFFFFB371), AppColors.warning],
  ),
];

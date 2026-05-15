import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import 'exercise_catalog_data.dart';

class ExerciseSelectScreen extends StatelessWidget {
  const ExerciseSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '운동하기',
      showBackButton: true,
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Text(
                      '어떤 부위를 운동할까요?',
                      style: AppTextStyles.title.copyWith(fontSize: 23),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '대분류를 먼저 고르면 다음 단계에서 운동 종목을 선택할 수 있어요.',
                      style: AppTextStyles.bodyLg,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          for (final category in exerciseCategoryOptions) ...[
            _ExerciseCategoryCard(
              category: category,
              exerciseCount: exercisesByCategory(category.id).length,
              onTap: () =>
                  context.push('/workout-exercises?category=${category.id}'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _ExerciseCategoryCard extends StatelessWidget {
  const _ExerciseCategoryCard({
    required this.category,
    required this.exerciseCount,
    required this.onTap,
  });

  final ExerciseCategoryOption category;
  final int exerciseCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasExercises = exerciseCount > 0;

    return ImoCard(
      interactive: true,
      onTap: onTap,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: category.gradient,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: category.gradient.last.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(category.icon, color: AppColors.card, size: 26),
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
                        category.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.sectionTitle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ImoChip(
                      label: hasExercises ? '$exerciseCount개 운동' : '준비중',
                      variant: hasExercises
                          ? ImoChipVariant.selected
                          : ImoChipVariant.outline,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(category.description, style: AppTextStyles.bodyLg),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.textTertiary,
            size: 22,
          ),
        ],
      ),
    );
  }
}

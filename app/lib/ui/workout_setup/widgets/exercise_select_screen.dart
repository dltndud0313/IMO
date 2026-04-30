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
      title: '운동하기',
      showBackButton: true,
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
                      '오늘은 어떤 운동을 할까요?',
                      style: AppTextStyles.title.copyWith(fontSize: 23),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '실시간 EMG·IMU 분석을 받을 수 있어요',
                      style: AppTextStyles.bodyLg,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          for (final exercise in _exerciseOptions) ...[
            _ExerciseOptionCard(
              option: exercise,
              onTap: () => context.go('/workout-guide?exercise=${exercise.id}'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _ExerciseOptionCard extends StatelessWidget {
  const _ExerciseOptionCard({required this.option, required this.onTap});

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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: option.gradient,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: option.gradient.last.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(option.icon, color: AppColors.card, size: 26),
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
                        style: AppTextStyles.sectionTitle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(option.titleEn, style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(option.target, style: AppTextStyles.bodyLg),
                const SizedBox(height: AppSpacing.xs),
                const ImoChip(label: '초급', variant: ImoChipVariant.selected),
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

class _ExerciseOption {
  const _ExerciseOption({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.target,
    required this.icon,
    required this.gradient,
  });

  final String id;
  final String title;
  final String titleEn;
  final String target;
  final IconData icon;
  final List<Color> gradient;
}

const _exerciseOptions = [
  _ExerciseOption(
    id: 'pushup',
    title: '푸시업',
    titleEn: 'Push-up',
    target: '가슴 · 삼두 · 어깨',
    icon: Icons.fitness_center_rounded,
    gradient: [AppColors.primary, AppColors.primaryStrong],
  ),
  _ExerciseOption(
    id: 'lateral_raise',
    title: '싸레레',
    titleEn: 'Lateral Raise',
    target: '어깨 (측면)',
    icon: Icons.accessibility_new_rounded,
    gradient: [AppColors.secondary, Color(0xFF5DC447)],
  ),
  _ExerciseOption(
    id: 'bicep_curl',
    title: '이두컬',
    titleEn: 'Bicep Curl',
    target: '이두근',
    icon: Icons.sports_gymnastics_rounded,
    gradient: [Color(0xFFFFB371), AppColors.warning],
  ),
];

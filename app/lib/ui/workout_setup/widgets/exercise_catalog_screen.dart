import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import 'exercise_catalog_data.dart';

class ExerciseCatalogScreen extends StatefulWidget {
  const ExerciseCatalogScreen({super.key, this.categoryId = 'upper'});

  final String categoryId;

  @override
  State<ExerciseCatalogScreen> createState() => _ExerciseCatalogScreenState();
}

class _ExerciseCatalogScreenState extends State<ExerciseCatalogScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  ExerciseCategoryOption get _category =>
      exerciseCategoryById(widget.categoryId);

  List<ExerciseCatalogItem> get _filteredExercises {
    return exercisesByCategory(
      widget.categoryId,
    ).where((exercise) => exercise.matches(_query)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _filteredExercises;
    final hasCategoryExercises = exercisesByCategory(
      widget.categoryId,
    ).isNotEmpty;

    return AppScaffold(
      title: _category.title,
      subtitle: '운동 종목 선택',
      showBackButton: true,
      onBack: () => context.go('/workout-setup'),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CategorySummaryCard(category: _category),
          const SizedBox(height: AppSpacing.sectionGap),
          ImoTextField(
            controller: _searchController,
            hint: '운동 이름, 부위로 검색',
            prefixIcon: const Icon(Icons.search_rounded),
            clearable: true,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          if (!hasCategoryExercises)
            const _ComingSoonCard()
          else if (exercises.isEmpty)
            _EmptySearchCard(query: _query)
          else
            for (final exercise in exercises) ...[
              _ExerciseOptionCard(
                exercise: exercise,
                onTap: exercise.enabled
                    ? () => context.go(
                        '/workout-guide?exercise=${exercise.id}'
                        '&category=${widget.categoryId}',
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
        ],
      ),
    );
  }
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({required this.category});

  final ExerciseCategoryOption category;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: category.gradient),
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            child: Icon(category.icon, color: AppColors.card, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${category.title} 운동', style: AppTextStyles.sectionTitle),
                const SizedBox(height: AppSpacing.xxs),
                Text(category.description, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseOptionCard extends StatelessWidget {
  const _ExerciseOptionCard({required this.exercise, required this.onTap});

  final ExerciseCatalogItem exercise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      interactive: onTap != null,
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
                colors: exercise.gradient,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: exercise.gradient.last.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(exercise.icon, color: AppColors.card, size: 26),
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
                        exercise.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.sectionTitle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(exercise.titleEn, style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(exercise.target, style: AppTextStyles.bodyLg),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    ImoChip(
                      label: exercise.levelLabel,
                      variant: ImoChipVariant.selected,
                    ),
                    ImoChip(label: 'Pi 지원', variant: ImoChipVariant.success),
                  ],
                ),
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

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.construction_rounded,
            color: AppColors.textTertiary,
            size: 28,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('아직 준비 중인 운동이에요', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          Text('현재 Pi 연동 운동은 상체 카테고리부터 지원합니다.', style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _EmptySearchCard extends StatelessWidget {
  const _EmptySearchCard({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.outlined,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: AppColors.textTertiary,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('"$query"에 맞는 운동이 없어요.', style: AppTextStyles.body),
          ),
        ],
      ),
    );
  }
}

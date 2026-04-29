import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../view_model/home_viewmodel.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return AppScaffold(
      title: 'IMO',
      subtitle: viewModel.statusLabel,
      scrollable: true,
      heroSlot: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Build today with better movement.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Ready for your next session?',
            style: AppTextStyles.sectionTitle,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TodaySummaryCard(),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('Start', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _HomeActionCard(
            title: 'Workout mode',
            description: 'Set exercise, reps, and rest time before connecting Pi.',
            icon: Icons.fitness_center_rounded,
            gradient: const [
              AppColors.primary,
              AppColors.primaryStrong,
            ],
            onTap: () => context.go('/workout-setup'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HomeActionCard(
            title: 'Recovery mode',
            description: 'Use the same flow for guided light movement sessions.',
            icon: Icons.monitor_heart_rounded,
            gradient: const [
              AppColors.secondary,
              Color(0xFF5DC447),
            ],
            onTap: () => context.go('/workout-setup'),
          ),
        ],
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard();

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
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.primaryStrong,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('Today summary', style: AppTextStyles.label),
              const Spacer(),
              const StatusBadge(
                label: 'Ready',
                variant: StatusVariant.info,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(
                child: _SummaryMetric(label: 'Sessions', value: '0', unit: ''),
              ),
              Expanded(
                child: _SummaryMetric(label: 'Reps', value: '0', unit: ''),
              ),
              Expanded(
                child: _SummaryMetric(label: 'Minutes', value: '0', unit: 'min'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: AppTextStyles.metric),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.xxs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: AppTextStyles.caption),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.largeCardPadding),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                  ),
                  child: Icon(icon, color: AppColors.card, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.card,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.card.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.card,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

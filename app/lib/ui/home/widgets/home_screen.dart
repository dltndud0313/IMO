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
    return AppScaffold(
      nested: true,
      title: '홈',
      scrollable: true,
      heroSlot: const _HomeGreeting(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TodaySummaryCard(),
          const SizedBox(height: AppSpacing.sectionGap),
          Text('오늘도 득근!', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _HomeActionCard(
            title: '운동하기',
            description: '근력 트레이닝 · EMG-IMU 분석',
            icon: Icons.fitness_center_rounded,
            gradient: const [AppColors.primary, AppColors.primaryStrong],
            onTap: () => context.push('/workout-setup'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HomeActionCard(
            title: '재활하기',
            description: '회복 운동 · 저강도 가동범위',
            icon: Icons.monitor_heart_rounded,
            gradient: const [AppColors.secondary, Color(0xFF5DC447)],
            onTap: () => _showRehabComingSoon(context),
          ),
        ],
      ),
    );
  }
}

void _showRehabComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('재활 모드는 준비 중이에요. 곧 만나보실 수 있어요!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final nickname =
        (vm.nickname?.isNotEmpty ?? false) ? vm.nickname! : '사용자';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(vm.greetingSubtitle, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '$nickname님, 안녕하세요!',
          style: AppTextStyles.title.copyWith(fontSize: 24),
        ),
      ],
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('오늘의 운동', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '세션',
                  value: '${vm.todaySessionCount}',
                  unit: '회',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '총 횟수',
                  value: '${vm.todayTotalReps}',
                  unit: '회',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  label: '시간',
                  value: '${vm.todayDurationMin}',
                  unit: '분',
                ),
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
        Text(label, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: AppTextStyles.metric),
            const SizedBox(width: AppSpacing.xxs),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(unit, style: AppTextStyles.caption),
            ),
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
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
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
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: AppColors.card,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.card.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.card,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

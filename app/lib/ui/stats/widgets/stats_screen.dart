import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../tabs/balance_tab.dart';
import '../tabs/heatmap_tab.dart';
import '../tabs/trend_tab.dart';
import 'stats_tab_bar.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsTab _selectedTab = StatsTab.heatmap;
  int _weekOffset = 0;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '통계',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsPeriodHeader(
            weekOffset: _weekOffset,
            onPrevious: () => setState(() => _weekOffset--),
            onNext: _weekOffset < 0 ? () => setState(() => _weekOffset++) : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          StatsTabBar(
            selectedTab: _selectedTab,
            onChanged: (tab) => setState(() => _selectedTab = tab),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (_selectedTab) {
              StatsTab.heatmap => const HeatmapTab(),
              StatsTab.balance => const BalanceTab(),
              StatsTab.trend => const TrendTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _StatsPeriodHeader extends StatelessWidget {
  const _StatsPeriodHeader({
    required this.weekOffset,
    required this.onPrevious,
    this.onNext,
  });

  final int weekOffset;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('4월 ${5 + weekOffset}주차', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xxs),
            Text('4월 27일 (월) - 5월 3일 (일)', style: AppTextStyles.body),
          ],
        ),
        const Spacer(),
        _RoundNavButton(
          icon: Icons.chevron_left_rounded,
          onTap: onPrevious,
        ),
        const SizedBox(width: AppSpacing.xs),
        _RoundNavButton(
          icon: Icons.chevron_right_rounded,
          disabled: onNext == null,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _RoundNavButton extends StatelessWidget {
  const _RoundNavButton({
    required this.icon,
    this.disabled = false,
    this.onTap,
  });

  final IconData icon;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.35 : 1,
      child: Material(
        color: AppColors.card,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: disabled ? null : onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../config/dependencies.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../tabs/balance_tab.dart';
import '../tabs/heatmap_tab.dart';
import '../tabs/trend_tab.dart';
import '../view_model/stats_viewmodel.dart';
import 'stats_tab_bar.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late final StatsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = getIt<StatsViewModel>();
    _viewModel.addListener(_handleViewModelChanged);
    if (!_viewModel.hasData) {
      _loadStats();
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChanged);
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadStats() {
    return _viewModel.loadSelectedWeekStats();
  }

  void _moveWeek(int delta) {
    _viewModel.moveWeek(delta);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      nested: true,
      title: '통계',
      scrollable: false,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatsPeriodHeader(
              weekStart: _viewModel.weekStart,
              onPrevious: () => _moveWeek(-1),
              onNext: _viewModel.weekOffset < 0 ? () => _moveWeek(1) : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_viewModel.loadError != null)
              _StatsInfoCard(message: _viewModel.loadError!)
            else ...[
              StatsTabBar(
                selectedTab: _viewModel.selectedTab,
                onChanged: (tab) => _viewModel.selectTab(tab),
              ),
              const SizedBox(height: AppSpacing.md),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _viewModel.loading && !_viewModel.hasData
                    ? const SizedBox(
                        key: ValueKey('stats-loading'),
                        height: 280,
                        child: Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      )
                    : switch (_viewModel.selectedTab) {
                        StatsTab.heatmap => HeatmapTab(
                            data: _viewModel.heatmap,
                            gender: _viewModel.gender,
                          ),
                        StatsTab.balance =>
                          BalanceTab(data: _viewModel.balance),
                        StatsTab.trend => TrendTab(
                            data: _viewModel.weeklyStats,
                            weekStart: _viewModel.weekStart,
                          ),
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsPeriodHeader extends StatelessWidget {
  const _StatsPeriodHeader({
    required this.weekStart,
    required this.onPrevious,
    this.onNext,
  });

  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${weekStart.month}월 ${((weekStart.day - 1) ~/ 7) + 1}주차', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${weekStart.month}월 ${weekStart.day}일 - ${weekEnd.month}월 ${weekEnd.day}일',
              style: AppTextStyles.body,
            ),
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

class _StatsInfoCard extends StatelessWidget {
  const _StatsInfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
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

import 'package:flutter/material.dart';

import '../../../config/dependencies.dart';
import '../../../data/services/api_service.dart';
import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
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
  bool _loading = true;
  String? _loadError;
  Map<String, dynamic>? _weeklyStats;
  Map<String, dynamic>? _heatmap;
  Map<String, dynamic>? _balance;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = getIt<ApiService>();
      final weekStart = _weekStartText;
      final results = await Future.wait([
        api.getWeeklyStats(weekStart),
        api.getWeeklyHeatmap(weekStart),
        api.getWeeklyBalance(weekStart),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _weeklyStats = results[0];
        _heatmap = results[1];
        _balance = results[2];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = '통계 정보를 불러오지 못했습니다.';
      });
    }
  }

  void _moveWeek(int delta) {
    setState(() => _weekOffset += delta);
    _loadStats();
  }

  DateTime get _weekStart {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final target = monday.add(Duration(days: _weekOffset * 7));
    return DateTime(target.year, target.month, target.day);
  }

  String get _weekStartText {
    final weekStart = _weekStart;
    final month = weekStart.month.toString().padLeft(2, '0');
    final day = weekStart.day.toString().padLeft(2, '0');
    return '${weekStart.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '통계',
      scrollable: false,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsPeriodHeader(
                  weekStart: _weekStart,
                  onPrevious: () => _moveWeek(-1),
                  onNext: _weekOffset < 0 ? () => _moveWeek(1) : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!_loading && _loadError == null) ...[
                  StatsTabBar(
                    selectedTab: _selectedTab,
                    onChanged: (tab) => setState(() => _selectedTab = tab),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: switch (_selectedTab) {
                      StatsTab.heatmap => HeatmapTab(data: _heatmap),
                      StatsTab.balance => BalanceTab(data: _balance),
                      StatsTab.trend => TrendTab(data: _weeklyStats),
                    },
                  ),
                ] else if (_loadError != null) ...[
                  _StatsInfoCard(message: _loadError!),
                ],
              ],
            ),
          ),
          if (_loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          '통계를 불러오는 중입니다',
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '잠시만 기다려주세요',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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

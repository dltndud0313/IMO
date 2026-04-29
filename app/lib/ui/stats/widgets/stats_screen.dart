import 'package:flutter/material.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

enum _StatsTab { heatmap, balance, trend }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _StatsTab _selectedTab = _StatsTab.heatmap;
  String _period = 'Week';
  String _exercise = 'All';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Stats',
      subtitle: 'Exercise analytics',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatsFilterBar(
            period: _period,
            exercise: _exercise,
            onPeriodChanged: (value) => setState(() => _period = value),
            onExerciseChanged: (value) => setState(() => _exercise = value),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const _StatsSummaryGrid(),
          const SizedBox(height: AppSpacing.sectionGap),
          _StatsTabBar(
            selectedTab: _selectedTab,
            onChanged: (tab) => setState(() => _selectedTab = tab),
          ),
          const SizedBox(height: AppSpacing.md),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (_selectedTab) {
              _StatsTab.heatmap => const _HeatmapStatsTab(),
              _StatsTab.balance => const _BalanceStatsTab(),
              _StatsTab.trend => const _TrendStatsTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _StatsFilterBar extends StatelessWidget {
  const _StatsFilterBar({
    required this.period,
    required this.exercise,
    required this.onPeriodChanged,
    required this.onExerciseChanged,
  });

  final String period;
  final String exercise;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<String> onExerciseChanged;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Query filters', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in const ['Week', 'Month', '3M'])
                ImoChip(
                  label: option,
                  selected: period == option,
                  onTap: () => onPeriodChanged(option),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in const [
                'All',
                'Push-up',
                'Lateral raise',
                'Bicep curl',
              ])
                ImoChip(
                  label: option,
                  selected: exercise == option,
                  variant: ImoChipVariant.outline,
                  onTap: () => onExerciseChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsSummaryGrid extends StatelessWidget {
  const _StatsSummaryGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.4,
      children: const [
        _StatsSummaryTile(label: 'Sessions', value: '12', color: AppColors.primary),
        _StatsSummaryTile(label: 'Total reps', value: '384', color: AppColors.success),
        _StatsSummaryTile(label: 'Valid rate', value: '92%', color: AppColors.secondary),
        _StatsSummaryTile(label: 'Compensation', value: '18', color: AppColors.warning),
      ],
    );
  }
}

class _StatsSummaryTile extends StatelessWidget {
  const _StatsSummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(Icons.analytics_rounded, color: color, size: 19),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.sectionTitle),
              const SizedBox(height: AppSpacing.xxs),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsTabBar extends StatelessWidget {
  const _StatsTabBar({
    required this.selectedTab,
    required this.onChanged,
  });

  final _StatsTab selectedTab;
  final ValueChanged<_StatsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardSubtle,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Row(
          children: [
            _StatsTabButton(
              label: 'Heatmap',
              selected: selectedTab == _StatsTab.heatmap,
              onTap: () => onChanged(_StatsTab.heatmap),
            ),
            _StatsTabButton(
              label: 'Balance',
              selected: selectedTab == _StatsTab.balance,
              onTap: () => onChanged(_StatsTab.balance),
            ),
            _StatsTabButton(
              label: 'Trend',
              selected: selectedTab == _StatsTab.trend,
              onTap: () => onChanged(_StatsTab.trend),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsTabButton extends StatelessWidget {
  const _StatsTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppColors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatmapStatsTab extends StatelessWidget {
  const _HeatmapStatsTab();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      key: const ValueKey('heatmap'),
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Muscle activation heatmap', style: AppTextStyles.label),
              const Spacer(),
              const StatusBadge(label: '2D', variant: StatusVariant.info),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: AppColors.heatmapBg,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Stack(
              children: const [
                Center(
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    size: 172,
                    color: AppColors.heatmapInactive,
                  ),
                ),
                _HeatmapLabel(label: 'Chest 85%', top: 72, left: 70, color: AppColors.heatmapHigh),
                _HeatmapLabel(label: 'Shoulder 72%', top: 58, right: 48, color: AppColors.heatmapNormal),
                _HeatmapLabel(label: 'Biceps 58%', top: 132, left: 38, color: AppColors.heatmapNormal),
                _HeatmapLabel(label: 'Triceps 42%', top: 142, right: 42, color: AppColors.heatmapLow),
                _HeatmapLabel(label: 'Core 31%', top: 198, left: 96, color: AppColors.heatmapLow),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(label: 'Low', color: AppColors.heatmapLow, showDot: false),
              StatusBadge(label: 'Normal', color: AppColors.heatmapNormal, showDot: false),
              StatusBadge(label: 'High', color: AppColors.heatmapHigh, showDot: false),
              StatusBadge(label: 'Danger', color: AppColors.heatmapDanger, showDot: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatmapLabel extends StatelessWidget {
  const _HeatmapLabel({
    required this.label,
    required this.top,
    required this.color,
    this.left,
    this.right,
  });

  final String label;
  final double top;
  final double? left;
  final double? right;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.card,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BalanceStatsTab extends StatelessWidget {
  const _BalanceStatsTab();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      key: const ValueKey('balance'),
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Left/right balance', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          for (final item in _balanceRows) ...[
            _BalanceRow(item: item),
            if (item != _balanceRows.last) const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.md),
          ImoCard(
            variant: ImoCardVariant.subtle,
            paddingSize: ImoCardPadding.md,
            child: Text(
              'Balance metrics are enabled only when sensor pairing supports left/right comparison.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.item});

  final _BalanceMetric item;

  @override
  Widget build(BuildContext context) {
    final diff = (item.left - item.right).abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(item.label, style: AppTextStyles.label),
            const Spacer(),
            StatusBadge(
              label: diff >= 10 ? 'Check' : 'Stable',
              variant: diff >= 10 ? StatusVariant.warning : StatusVariant.success,
              showDot: false,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _BalanceBar(
                value: item.left,
                alignRight: true,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _BalanceBar(
                value: item.right,
                alignRight: false,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Left ${item.left}% · Right ${item.right}%', style: AppTextStyles.caption),
      ],
    );
  }
}

class _BalanceBar extends StatelessWidget {
  const _BalanceBar({
    required this.value,
    required this.alignRight,
    required this.color,
  });

  final int value;
  final bool alignRight;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.cardSubtle,
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(alignRight ? AppSpacing.sm : AppSpacing.xxs),
          right: Radius.circular(alignRight ? AppSpacing.xxs : AppSpacing.sm),
        ),
      ),
      child: FractionallySizedBox(
        widthFactor: value / 100,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(alignRight ? AppSpacing.sm : AppSpacing.xxs),
              right: Radius.circular(alignRight ? AppSpacing.xxs : AppSpacing.sm),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendStatsTab extends StatelessWidget {
  const _TrendStatsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('trend'),
      children: const [
        _TrendCard(
          title: 'Target activation',
          values: [55, 62, 68, 70, 72, 75, 78],
          color: AppColors.primary,
          unit: '%',
        ),
        SizedBox(height: AppSpacing.md),
        _TrendCard(
          title: 'Fatigue signal',
          values: [40, 45, 55, 50, 62, 70, 68],
          color: AppColors.warning,
          unit: '%',
        ),
        SizedBox(height: AppSpacing.md),
        _TrendCard(
          title: 'Compensation count',
          values: [5, 4, 6, 3, 4, 2, 3],
          color: AppColors.error,
          unit: '',
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.values,
    required this.color,
    required this.unit,
  });

  final String title;
  final List<int> values;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(1, (current, value) => value > current ? value : current);

    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 148,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < values.length; index++) ...[
                  Expanded(
                    child: _TrendBar(
                      value: values[index],
                      max: max,
                      color: color,
                      unit: unit,
                      day: _days[index],
                    ),
                  ),
                  if (index != values.length - 1) const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.value,
    required this.max,
    required this.color,
    required this.unit,
    required this.day,
  });

  final int value;
  final int max;
  final Color color;
  final String unit;
  final String day;

  @override
  Widget build(BuildContext context) {
    final heightFactor = value / max;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$value$unit', style: AppTextStyles.caption.copyWith(fontSize: 10)),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor.clamp(0.05, 1),
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.xs),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(day, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}

class _BalanceMetric {
  const _BalanceMetric({
    required this.label,
    required this.left,
    required this.right,
  });

  final String label;
  final int left;
  final int right;
}

const _balanceRows = [
  _BalanceMetric(label: 'Chest', left: 78, right: 82),
  _BalanceMetric(label: 'Shoulder', left: 65, right: 72),
  _BalanceMetric(label: 'Triceps', left: 71, right: 74),
];

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

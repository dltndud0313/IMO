import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';

enum StatsTab { heatmap, balance, trend }

class StatsTabBar extends StatelessWidget {
  const StatsTabBar({
    super.key,
    required this.selectedTab,
    required this.onChanged,
  });

  final StatsTab selectedTab;
  final ValueChanged<StatsTab> onChanged;

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
              label: '히트맵',
              selected: selectedTab == StatsTab.heatmap,
              onTap: () => onChanged(StatsTab.heatmap),
            ),
            _StatsTabButton(
              label: '밸런스',
              selected: selectedTab == StatsTab.balance,
              onTap: () => onChanged(StatsTab.balance),
            ),
            _StatsTabButton(
              label: '추세',
              selected: selectedTab == StatsTab.trend,
              onTap: () => onChanged(StatsTab.trend),
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
              style: AppTextStyles.bodyLg.copyWith(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

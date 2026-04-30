import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/layouts/app_scaffold.dart';
import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '운동 기록',
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MonthSelector(),
          const SizedBox(height: AppSpacing.md),
          const _CalendarCard(),
          const SizedBox(height: AppSpacing.lg),
          Text('2026-4-29 요약', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          _DaySummaryCard(
            onTap: () =>
                context.go('/history-detail?session=sess_20260429_001'),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleIconButton(icon: Icons.chevron_left_rounded, onTap: () {}),
        const SizedBox(width: AppSpacing.xs),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Text('2026년 4월', style: AppTextStyles.sectionTitle),
        ),
        const SizedBox(width: AppSpacing.xs),
        _CircleIconButton(icon: Icons.chevron_right_rounded, onTap: () {}),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard();

  @override
  Widget build(BuildContext context) {
    const days = ['일', '월', '화', '수', '목', '금', '토'];
    final dates =
        List<int?>.filled(3, null) + List<int>.generate(30, (i) => i + 1);

    return ImoCard(
      variant: ImoCardVariant.hero,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.25,
            children: [
              for (final day in days)
                Center(
                  child: Text(
                    day,
                    style: AppTextStyles.caption.copyWith(
                      color: day == '일'
                          ? AppColors.error
                          : day == '토'
                          ? AppColors.heatmapLow
                          : AppColors.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              for (final date in dates)
                Center(
                  child: date == null
                      ? const SizedBox.shrink()
                      : _DateCell(date: date),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({required this.date});

  final int date;

  @override
  Widget build(BuildContext context) {
    final selected = date == 29;
    return Container(
      width: selected ? 52 : 36,
      height: selected ? 52 : 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(
          selected ? AppSpacing.buttonRadius : 18,
        ),
      ),
      child: Text(
        '$date',
        style: AppTextStyles.body.copyWith(
          color: selected ? AppColors.card : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      interactive: true,
      onTap: onTap,
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('푸시업', style: AppTextStyles.sectionTitle),
              const Spacer(),
              Text('30회 · 1분', style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '하루 상세 분석 보기',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primaryStrong,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryStrong,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

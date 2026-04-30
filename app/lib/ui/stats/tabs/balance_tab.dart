import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class BalanceTab extends StatelessWidget {
  const BalanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: ValueKey('balance'),
      children: [
        _BalanceCard(),
        SizedBox(height: AppSpacing.md),
        _BalanceNotice(),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('좌우 밸런스', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          const _BalanceRow(label: '가슴', left: 85, right: 78),
          const _BalanceRow(label: '삼두근', left: 72, right: 75),
          const _BalanceRow(label: '어깨', left: 68, right: 82),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.left,
    required this.right,
  });

  final String label;
  final int left;
  final int right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.label),
              const Spacer(),
              Text('좌 $left% · 우 $right%', style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
            child: Row(
              children: [
                const Spacer(flex: 1),
                Expanded(
                  flex: left,
                  child: Container(height: 34, color: AppColors.primary),
                ),
                Container(width: 5, height: 34, color: AppColors.card),
                Expanded(
                  flex: right,
                  child: Container(height: 34, color: AppColors.secondary),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceNotice extends StatelessWidget {
  const _BalanceNotice();

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Text(
        '좌우 밸런스가 10% 이상 차이날 경우 보상 위험이 증가할 수 있습니다.',
        style: AppTextStyles.body,
      ),
    );
  }
}

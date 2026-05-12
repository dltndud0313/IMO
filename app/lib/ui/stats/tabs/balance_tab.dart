import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../widgets/stats_empty_state.dart';

class BalanceTab extends StatelessWidget {
  const BalanceTab({super.key, this.data});

  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final pairs = (data?['balancePairs'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        const <Map<String, dynamic>>[];
    if (pairs.isEmpty) {
      return ImoCard(
        key: const ValueKey('balance'),
        paddingSize: ImoCardPadding.lg,
        child: const StatsEmptyState(
          icon: Icons.compare_arrows,
          message: '이번 주 밸런스 데이터가 없습니다',
          subMessage: '운동 후 좌우 근활성도 비교 결과가 표시됩니다',
        ),
      );
    }
    return Column(
      key: const ValueKey('balance'),
      children: [
        _BalanceCard(pairs: pairs),
        const SizedBox(height: AppSpacing.md),
        const _BalanceNotice(),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.pairs});

  final List<Map<String, dynamic>> pairs;

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('좌우 밸런스', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          for (final pair in pairs)
            _BalanceRow(
              label: pair['muscleName']?.toString() ?? 'unknown',
              left: _avgActivation(pair['left']),
              right: _avgActivation(pair['right']),
            ),
        ],
      ),
    );
  }
}

int _avgActivation(dynamic value) {
  if (value is Map<String, dynamic>) {
    return ((value['avgActivation'] as num?)?.toDouble() ?? 0).round();
  }
  return 0;
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
                  flex: left.clamp(1, 100),
                  child: Container(height: 34, color: AppColors.primary),
                ),
                Container(width: 5, height: 34, color: AppColors.card),
                Expanded(
                  flex: right.clamp(1, 100),
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

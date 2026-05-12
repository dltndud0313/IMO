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
      return SizedBox(
        key: const ValueKey('balance'),
        width: double.infinity,
        height: 280,
        child: ImoCard(
          paddingSize: ImoCardPadding.lg,
          child: const Center(
            child: StatsEmptyState(
              icon: Icons.compare_arrows,
              message: '이번 주 밸런스 데이터가 없습니다',
              subMessage: '운동 후 좌우 근활성도 비교 결과가 표시됩니다',
            ),
          ),
        ),
      );
    }
    return Column(
      key: const ValueKey('balance'),
      children: [
        _BalanceCard(pairs: pairs),
        const SizedBox(height: AppSpacing.md),
        _BalanceNotice(pairs: pairs),
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

Color _balanceColor(int diff) {
  if (diff < 5) return AppColors.success;
  if (diff < 10) return AppColors.warning;
  return AppColors.heatmapDanger;
}

(String, IconData) _balanceStatus(int diff) {
  if (diff < 5) return ('균형', Icons.check_circle);
  if (diff < 10) return ('주의', Icons.warning_rounded);
  return ('위험', Icons.dangerous_rounded);
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
    final diff = (left - right).abs();
    final color = _balanceColor(diff);
    final (statusLabel, statusIcon) = _balanceStatus(diff);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTextStyles.label),
              const Spacer(),
              Icon(statusIcon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: AppTextStyles.caption.copyWith(color: color),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('좌 $left% · 우 $right%', style: AppTextStyles.body),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 34,
            child: Row(
              children: [
                // 좌측 영역 — 막대가 중앙 쪽(오른쪽)으로 정렬
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppSpacing.pillRadius),
                      bottomLeft: Radius.circular(AppSpacing.pillRadius),
                    ),
                    child: ColoredBox(
                      color: AppColors.cardSubtle,
                      child: Row(
                        children: [
                          Spacer(flex: (100 - left).clamp(0, 100)),
                          Flexible(
                            flex: left.clamp(1, 100),
                            child: ColoredBox(color: color, child: const SizedBox.expand()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 중앙 기준선
                Container(width: 2, color: AppColors.divider),
                // 우측 영역 — 막대가 중앙 쪽(왼쪽)으로 정렬
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(AppSpacing.pillRadius),
                      bottomRight: Radius.circular(AppSpacing.pillRadius),
                    ),
                    child: ColoredBox(
                      color: AppColors.cardSubtle,
                      child: Row(
                        children: [
                          Flexible(
                            flex: right.clamp(1, 100),
                            child: ColoredBox(color: color, child: const SizedBox.expand()),
                          ),
                          Spacer(flex: (100 - right).clamp(0, 100)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceNotice extends StatelessWidget {
  const _BalanceNotice({required this.pairs});

  final List<Map<String, dynamic>> pairs;

  @override
  Widget build(BuildContext context) {
    final diffs = [
      for (final pair in pairs)
        (
          name: pair['muscleName']?.toString() ?? 'unknown',
          diff: (_avgActivation(pair['left']) - _avgActivation(pair['right']))
              .abs(),
        ),
    ];

    final imbalanced = diffs.where((d) => d.diff >= 5).toList()
      ..sort((a, b) => b.diff.compareTo(a.diff));

    if (imbalanced.isEmpty) {
      return ImoCard(
        variant: ImoCardVariant.subtle,
        paddingSize: ImoCardPadding.lg,
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: AppColors.success),
            const SizedBox(width: AppSpacing.xs),
            Text('좌우 균형이 양호합니다', style: AppTextStyles.body),
          ],
        ),
      );
    }

    final worst = imbalanced.first;
    final extra = imbalanced.length - 1;
    final message = extra > 0
        ? '${worst.name}의 좌우 차이가 ${worst.diff}%입니다 (외 $extra개 근육)'
        : '${worst.name}의 좌우 차이가 ${worst.diff}%입니다';

    return ImoCard(
      variant: ImoCardVariant.subtle,
      paddingSize: ImoCardPadding.lg,
      child: Row(
        children: [
          Icon(Icons.warning_rounded, size: 16, color: AppColors.heatmapDanger),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.heatmapDanger),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../widgets/stats_empty_state.dart';

class TrendTab extends StatelessWidget {
  const TrendTab({super.key, this.data});

  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final trends = data?['trends'] as Map<String, dynamic>?;
    final fatigue = _trendValues(trends, 'fatigue');
    final targetActivation = _trendValues(trends, 'targetActivation');
    final compensationRate = _trendValues(trends, 'compensationRate');

    if (fatigue.isEmpty && targetActivation.isEmpty && compensationRate.isEmpty) {
      return ImoCard(
        key: const ValueKey('trend'),
        paddingSize: ImoCardPadding.lg,
        child: const StatsEmptyState(
          icon: Icons.show_chart,
          message: '이번 주 추세 데이터가 없습니다',
          subMessage: '운동 기록이 쌓이면 주간 추세가 표시됩니다',
        ),
      );
    }

    return Column(
      key: const ValueKey('trend'),
      children: [
        _TrendCard(
          title: '근피로도 추세',
          values: fatigue,
          color: AppColors.warning,
          unit: '%',
        ),
        const SizedBox(height: AppSpacing.md),
        _TrendCard(
          title: '목표근 사용 추세',
          values: targetActivation,
          color: AppColors.primary,
          unit: '%',
        ),
        const SizedBox(height: AppSpacing.md),
        _TrendCard(
          title: '보상동작 추세',
          values: compensationRate,
          color: AppColors.error,
          unit: '%',
        ),
      ],
    );
  }
}

List<int> _trendValues(Map<String, dynamic>? trends, String key) {
  final trend = trends?[key] as Map<String, dynamic>?;
  final values = (trend?['values'] as List?)
          ?.whereType<num>()
          .map((value) => value.round())
          .take(7)
          .toList() ??
      const <int>[];
  return values;
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
    return ImoCard(
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (values.isNotEmpty && i < values.length)
                          Text('${values[i]}$unit', style: AppTextStyles.caption),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          height: values.isNotEmpty && i < values.length ? 6 : 60,
                          decoration: BoxDecoration(
                            color:
                                values.isNotEmpty && i < values.length
                                    ? color
                                    : AppColors.cardSubtle,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.pillRadius,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          width: 20,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.cardSubtle,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.pillRadius,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i != 6) const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

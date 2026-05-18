import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../widgets/stats_empty_state.dart';

class TrendTab extends StatelessWidget {
  const TrendTab({super.key, this.data, this.weekStart});

  final Map<String, dynamic>? data;
  final DateTime? weekStart;

  @override
  Widget build(BuildContext context) {
    final trends = data?['trends'] as Map<String, dynamic>?;
    final targetActivation = _trendValues(trends, 'targetActivation');
    final compensationRate = _trendValues(trends, 'compensationRate');

    // 근피로도 카드는 Pi 측 onset 측정 알고리즘이 들어오기 전까지 노출 보류.
    // (백엔드는 0 으로 채워 보내고 있음)

    if (targetActivation.isEmpty && compensationRate.isEmpty) {
      return SizedBox(
        key: const ValueKey('trend'),
        width: double.infinity,
        height: 280,
        child: ImoCard(
          paddingSize: ImoCardPadding.lg,
          child: const Center(
            child: StatsEmptyState(
              icon: Icons.show_chart,
              message: '이번 주 추세 데이터가 없습니다',
              subMessage: '운동 기록이 쌓이면 주간 추세가 표시됩니다',
            ),
          ),
        ),
      );
    }

    final dayLabels = _buildDayLabels(weekStart);

    return Column(
      key: const ValueKey('trend'),
      children: [
        _TrendCard(
          title: '목표근 사용 추세',
          values: targetActivation,
          color: AppColors.primary,
          unit: '%',
          dayLabels: dayLabels,
        ),
        const SizedBox(height: AppSpacing.md),
        _TrendCard(
          title: '보상동작 추세',
          values: compensationRate,
          color: AppColors.error,
          unit: '%',
          dayLabels: dayLabels,
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

List<String> _buildDayLabels(DateTime? weekStart) {
  const labels = ['일', '월', '화', '수', '목', '금', '토'];
  if (weekStart == null) return labels;
  return List.generate(7, (i) {
    final day = weekStart.add(Duration(days: i));
    return labels[day.weekday % 7];
  });
}

const double _maxBarHeight = 80.0;

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.values,
    required this.color,
    required this.unit,
    required this.dayLabels,
  });

  final String title;
  final List<int> values;
  final Color color;
  final String unit;
  final List<String> dayLabels;

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
                        SizedBox(
                          height: 16,
                          child: values.isNotEmpty &&
                                  i < values.length &&
                                  values[i] > 0
                              ? Text(
                                  '${values[i]}$unit',
                                  style: AppTextStyles.caption,
                                  textAlign: TextAlign.center,
                                )
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        // pillRadius(999) 를 그대로 쓰면 작은 막대가 알약/원으로
                        // 변형되어 보이지 않는다. 가로폭을 제한하고 모서리 반경을
                        // 작게 잡아 세로 막대 모양을 유지한다.
                        SizedBox(
                          width: 16,
                          child: Container(
                            height: values.isNotEmpty &&
                                    i < values.length &&
                                    values[i] > 0
                                ? (values[i] / 100.0 * _maxBarHeight)
                                    .clamp(4.0, _maxBarHeight)
                                : 4.0,
                            decoration: BoxDecoration(
                              color: values.isNotEmpty &&
                                      i < values.length &&
                                      values[i] > 0
                                  ? color
                                  : AppColors.cardSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          dayLabels[i],
                          style: AppTextStyles.caption,
                          textAlign: TextAlign.center,
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

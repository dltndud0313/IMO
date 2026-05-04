import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class TrendTab extends StatelessWidget {
  const TrendTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      key: ValueKey('trend'),
      children: [
        _TrendCard(
          title: '근피로도 추세',
          values: [40, 45, 55, 50, 62, 70, 68],
          color: AppColors.warning,
          unit: '%',
        ),
        SizedBox(height: AppSpacing.md),
        _TrendCard(
          title: '목표근 사용 추세',
          values: [55, 62, 68, 70, 72, 75, 78],
          color: AppColors.primary,
          unit: '%',
        ),
        SizedBox(height: AppSpacing.md),
        _TrendCard(
          title: '보상동작 추세',
          values: [5, 4, 6, 3, 4, 2, 3],
          color: AppColors.error,
          unit: '회',
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
                for (var i = 0; i < values.length; i++) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${values[i]}$unit', style: AppTextStyles.caption),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.pillRadius,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(_days[i], style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  if (i != values.length - 1)
                    const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _days = ['월', '화', '수', '목', '금', '토', '일'];

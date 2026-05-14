import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/imo_card.dart';

class SmartglassMetricsStrip extends StatelessWidget {
  const SmartglassMetricsStrip({
    super.key,
    required this.workoutLabel,
    required this.repCount,
    required this.targetRep,
    required this.setProgressLabel,
    required this.paceLabel,
    required this.activationPercent,
    required this.activationLabel,
    required this.restSeconds,
    required this.connectionSummary,
  });

  final String workoutLabel;
  final int repCount;
  final int targetRep;
  final String setProgressLabel;
  final String paceLabel;
  final int activationPercent;
  final String activationLabel;
  final int restSeconds;
  final String connectionSummary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _MetricCard(
              width: compact ? constraints.maxWidth : 220,
              label: '운동',
              value: workoutLabel,
              note: setProgressLabel,
            ),
            _MetricCard(
              width: compact ? constraints.maxWidth : 180,
              label: '횟수',
              value: targetRep > 0 ? '$repCount / $targetRep' : '-',
              note: '현재 세트 기준',
              valueColor: AppColors.primaryStrong,
            ),
            _MetricCard(
              width: compact ? constraints.maxWidth : 160,
              label: '속도',
              value: paceLabel,
              note: '반복 리듬',
              valueColor: _paceColor(paceLabel),
            ),
            _MetricCard(
              width: compact ? constraints.maxWidth : 200,
              label: '근활성도',
              value: '$activationPercent%',
              note: activationLabel,
              valueColor: _activationColor(activationPercent),
            ),
            _MetricCard(
              width: compact ? constraints.maxWidth : 170,
              label: '휴식',
              value: restSeconds > 0 ? '${restSeconds}s' : '진행 중',
              note: restSeconds > 0 ? '다음 세트까지' : '측정 활성',
            ),
            _MetricCard(
              width: compact ? constraints.maxWidth : 200,
              label: '연결/소스',
              value: connectionSummary,
              note: 'Pi 실연동 전 preview 기반',
            ),
          ],
        );
      },
    );
  }

  Color _paceColor(String paceLabel) {
    switch (paceLabel) {
      case '빠름':
        return AppColors.warning;
      case '느림':
        return AppColors.error;
      case '적정':
        return AppColors.success;
      default:
        return AppColors.primaryStrong;
    }
  }

  Color _activationColor(int percent) {
    if (percent >= 70) return AppColors.success;
    if (percent >= 40) return AppColors.primaryStrong;
    if (percent > 0) return AppColors.warning;
    return AppColors.textSecondary;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.note,
    this.valueColor,
  });

  final double width;
  final String label;
  final String value;
  final String note;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ImoCard(
        paddingSize: ImoCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTextStyles.metric.copyWith(
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(note, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

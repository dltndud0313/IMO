import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';

class TrunkPostureIndicator extends StatelessWidget {
  const TrunkPostureIndicator({super.key, required this.stability});

  // 0.0~1.0, null이면 no data
  final double? stability;

  @override
  Widget build(BuildContext context) {
    final color = _color(stability);
    final qualLabel = _qualLabel(stability);
    final percentText = stability != null
        ? '${(stability! * 100).round()}%'
        : '-';
/// 운동 중 IMU 센서 기반으로 측정한 자세 안정도를 표시한다.
/// 
/// 0% = 자세 무너짐, 100% = 자세 완벽.
/// EMG 기반 복근 활성도와는 별개 지표이며, 모든 운동에서 공통 표시된다.
/// 향후 코어 운동 추가 시에도 본 위젯의 데이터 소스는 변하지 않는다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('자세 안정성', style: AppTextStyles.label),
            const Spacer(),
            Text(percentText, style: AppTextStyles.label),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: stability ?? 0,
            minHeight: 8,
            color: color,
            backgroundColor: AppColors.disabledBg,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          qualLabel,
          style: AppTextStyles.caption.copyWith(color: color),
        ),
      ],
    );
  }

  static Color _color(double? v) {
    if (v == null) return AppColors.textTertiary;
    if (v < 0.4) return AppColors.error;
    if (v < 0.7) return AppColors.warning;
    return AppColors.success;
  }

  static String _qualLabel(double? v) {
    if (v == null) return '측정 데이터 없음';
    if (v < 0.4) return '불안정';
    if (v < 0.7) return '보통';
    return '안정';
  }
}

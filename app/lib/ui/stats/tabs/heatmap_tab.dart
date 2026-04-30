import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';

class HeatmapTab extends StatelessWidget {
  const HeatmapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ImoCard(
      key: const ValueKey('heatmap'),
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('근활성도를 한 눈에 확인하세요!', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.md),
          const _MiniSegmentedControl(left: '전면', right: '후면'),
          const SizedBox(height: AppSpacing.lg),
          const SizedBox(
            height: 390,
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.accessibility_new_rounded,
                    size: 168,
                    color: Color(0x22EF4444),
                  ),
                ),
                _MuscleLabel(label: '어깨\n7%\n2일 전', top: 56, left: 8),
                _MuscleLabel(label: '가슴\n7%\n2일 전', top: 126, left: 8),
                _MuscleLabel(label: '이두\n7%\n2일 전', top: 196, left: 8),
                _MuscleLabel(label: '복근\n7%\n2일 전', top: 266, left: 8),
                _MuscleLabel(label: '상부 승모근\n7%\n2일 전', top: 56, right: 8),
                _MuscleLabel(label: '전완근\n7%\n2일 전', top: 176, right: 8),
                _MuscleLabel(label: '햄스트링\n7%\n2일 전', top: 266, right: 8),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.heatmapLow, label: '낮음'),
              SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.heatmapNormal, label: '보통'),
              SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.heatmapHigh, label: '높음'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSegmentedControl extends StatelessWidget {
  const _MiniSegmentedControl({required this.left, required this.right});

  final String left;
  final String right;

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
            Expanded(child: _MiniSegment(label: left, selected: true)),
            Expanded(child: _MiniSegment(label: right)),
          ],
        ),
      ),
    );
  }
}

class _MiniSegment extends StatelessWidget {
  const _MiniSegment({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.card : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.heatmapBg.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(label, style: AppTextStyles.label),
    );
  }
}

class _MuscleLabel extends StatelessWidget {
  const _MuscleLabel({
    required this.label,
    required this.top,
    this.left,
    this.right,
  });

  final String label;
  final double top;
  final double? left;
  final double? right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Text(
        label,
        textAlign: right == null ? TextAlign.left : TextAlign.right,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

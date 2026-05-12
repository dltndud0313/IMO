import 'package:flutter/material.dart';

import '../../core/themes/design_tokens.dart';
import '../../core/widgets/common_widgets.dart';
import '../models/body_heatmap_region.dart';
import '../models/body_heatmap_region_adapter.dart' show buildBodyHeatmapRegionsFromData;
import '../widgets/svg_body_heatmap_view.dart';
import '../widgets/trunk_posture_indicator.dart';

class HeatmapTab extends StatefulWidget {
  const HeatmapTab({super.key, this.data, this.gender = BodyGender.male});

  final Map<String, dynamic>? data;
  final BodyGender gender;

  @override
  State<HeatmapTab> createState() => _HeatmapTabState();
}

class _HeatmapTabState extends State<HeatmapTab> {
  bool _frontSelected = true;

  @override
  Widget build(BuildContext context) {
    final regions = buildBodyHeatmapRegionsFromData(widget.data);
    final selectedSide = _frontSelected
        ? BodyHeatmapViewSide.front
        : BodyHeatmapViewSide.back;
    final postureRegion = regions.where((r) => r.isPostureIndicator).firstOrNull;
    final stability = postureRegion?.percent != null
        ? (postureRegion!.percent! / 100.0).clamp(0.0, 1.0)
        : null;

    return ImoCard(
      key: const ValueKey('heatmap'),
      paddingSize: ImoCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('근활성도를 한 눈에 확인하세요!', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.md),
          _MiniSegmentedControl(
            left: '전면',
            right: '후면',
            leftSelected: _frontSelected,
            onLeftTap: () => setState(() => _frontSelected = true),
            onRightTap: () => setState(() => _frontSelected = false),
          ),
          const SizedBox(height: AppSpacing.lg),
          SvgBodyHeatmapView(
            regions: regions,
            selectedSide: selectedSide,
            gender: widget.gender,
          ),
          const SizedBox(height: AppSpacing.md),
          TrunkPostureIndicator(stability: stability),
          const SizedBox(height: AppSpacing.md),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppColors.heatmapLow, label: '낮음'),
              SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.heatmapNormal, label: '보통'),
              SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.heatmapHigh, label: '높음'),
              SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.heatmapDanger, label: '위험'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSegmentedControl extends StatelessWidget {
  const _MiniSegmentedControl({
    required this.left,
    required this.right,
    required this.leftSelected,
    required this.onLeftTap,
    required this.onRightTap,
  });

  final String left;
  final String right;
  final bool leftSelected;
  final VoidCallback onLeftTap;
  final VoidCallback onRightTap;

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
            Expanded(
              child: _MiniSegment(
                label: left,
                selected: leftSelected,
                onTap: onLeftTap,
              ),
            ),
            Expanded(
              child: _MiniSegment(
                label: right,
                selected: !leftSelected,
                onTap: onRightTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniSegment extends StatelessWidget {
  const _MiniSegment({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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

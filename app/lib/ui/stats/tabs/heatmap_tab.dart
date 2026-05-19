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
    final hasAnyData = regions.any((r) => !r.isPostureIndicator && r.hasData);

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
          const _ActivityGradientBar(),
          if (!hasAnyData) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '이번 주 측정 데이터가 없습니다',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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


class _ActivityGradientBar extends StatelessWidget {
  const _ActivityGradientBar();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('근활성도 범위', style: AppTextStyles.label),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.heatmapLow,
                  AppColors.heatmapNormal,
                  AppColors.heatmapHigh,
                  AppColors.heatmapDanger,
                ],
                stops: [0.0, 0.33, 0.66, 1.0],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('낮음', style: AppTextStyles.caption),
            Text('높음', style: AppTextStyles.caption),
          ],
        ),
      ],
    );
  }
}

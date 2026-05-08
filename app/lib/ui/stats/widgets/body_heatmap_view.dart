import 'package:flutter/material.dart';

import '../models/body_heatmap_region.dart';
import 'back_body_heatmap_painter.dart';
import 'front_body_heatmap_painter.dart';

class BodyHeatmapView extends StatelessWidget {
  const BodyHeatmapView({
    super.key,
    required this.regions,
    this.selectedSide = BodyHeatmapViewSide.front,
    this.height = 390,
  });

  final List<BodyHeatmapRegion> regions;
  final BodyHeatmapViewSide selectedSide;
  final double height;

  @override
  Widget build(BuildContext context) {
    final painter = selectedSide == BodyHeatmapViewSide.back
        ? BackBodyHeatmapPainter(regions: regions)
        : FrontBodyHeatmapPainter(regions: regions);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: painter, child: const SizedBox.expand()),
    );
  }
}

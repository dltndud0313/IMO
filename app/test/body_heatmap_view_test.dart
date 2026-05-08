import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imo/domain/models/muscle_map_schema.dart';
import 'package:imo/ui/stats/models/body_heatmap_region.dart';
import 'package:imo/ui/stats/widgets/back_body_heatmap_painter.dart';
import 'package:imo/ui/stats/widgets/body_heatmap_view.dart';
import 'package:imo/ui/stats/widgets/front_body_heatmap_painter.dart';

void main() {
  testWidgets('uses front painter by default', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: BodyHeatmapView(regions: _regions),
      ),
    );

    final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
    expect(customPaint.painter, isA<FrontBodyHeatmapPainter>());
  });

  testWidgets('uses back painter when selected side is back', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: BodyHeatmapView(
          regions: _regions,
          selectedSide: BodyHeatmapViewSide.back,
        ),
      ),
    );

    final customPaint = tester.widget<CustomPaint>(find.byType(CustomPaint));
    expect(customPaint.painter, isA<BackBodyHeatmapPainter>());
  });
}

const _regions = [
  BodyHeatmapRegion(
    key: 'left_chest',
    displayName: 'Left chest',
    viewSide: BodyHeatmapViewSide.front,
    kind: MuscleMapValueKind.activation,
    percent: 68,
    sessionCount: 4,
  ),
  BodyHeatmapRegion(
    key: 'left_triceps',
    displayName: 'Left triceps',
    viewSide: BodyHeatmapViewSide.back,
    kind: MuscleMapValueKind.activation,
    percent: null,
    sessionCount: 0,
  ),
  BodyHeatmapRegion(
    key: 'trunk',
    displayName: 'Trunk',
    viewSide: BodyHeatmapViewSide.posture,
    kind: MuscleMapValueKind.postureStability,
    percent: 72,
    sessionCount: 4,
  ),
];

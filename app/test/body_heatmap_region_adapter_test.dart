import 'package:flutter_test/flutter_test.dart';
import 'package:imo/domain/models/muscle_map_schema.dart';
import 'package:imo/ui/stats/models/body_heatmap_region.dart';
import 'package:imo/ui/stats/models/body_heatmap_region_adapter.dart';

void main() {
  test('normalizes ratio and percent activation values', () {
    expect(normalizeHeatmapActivation(0), 0);
    expect(normalizeHeatmapActivation(0.68), 68);
    expect(normalizeHeatmapActivation(65.3), 65.3);
    expect(normalizeHeatmapActivation(120), 100);
    expect(normalizeHeatmapActivation(-0.2), 0);
    expect(normalizeHeatmapActivation(null), isNull);
  });

  test('builds pushup regions with null for missing data', () {
    final regions = buildBodyHeatmapRegionsFromData(const {
      'muscles': [
        {
          'muscleId': 'left_chest',
          'muscleName': 'Left chest',
          'avgActivation': 0.68,
          'sessionCount': 4,
        },
        {
          'muscleId': 'right_triceps',
          'muscleName': 'Right triceps',
          'avgActivation': 0,
          'sessionCount': 4,
        },
      ],
    }, exerciseId: 'pushup');

    expect(regions.map((region) => region.key), [
      'left_chest',
      'right_chest',
      'left_triceps',
      'right_triceps',
      'trunk',
    ]);

    final leftChest = regions.firstWhere(
      (region) => region.key == 'left_chest',
    );
    expect(leftChest.percent, 68);
    expect(leftChest.hasData, isTrue);
    expect(leftChest.viewSide, BodyHeatmapViewSide.front);

    final rightChest = regions.firstWhere(
      (region) => region.key == 'right_chest',
    );
    expect(rightChest.percent, isNull);
    expect(rightChest.hasData, isFalse);

    final rightTriceps = regions.firstWhere(
      (region) => region.key == 'right_triceps',
    );
    expect(rightTriceps.percent, 0);
    expect(rightTriceps.hasData, isTrue);
    expect(rightTriceps.viewSide, BodyHeatmapViewSide.back);
  });

  test('separates trunk as a posture indicator', () {
    final regions = buildBodyHeatmapRegionsFromData(const {
      'muscles': [
        {
          'muscleId': 'trunk',
          'muscleName': 'Trunk stability',
          'avgActivation': 0.72,
          'sessionCount': 3,
        },
      ],
    }, exerciseId: 'lateral_raise');

    final trunk = regions.firstWhere((region) => region.key == 'trunk');
    expect(trunk.percent, 72);
    expect(trunk.viewSide, BodyHeatmapViewSide.posture);
    expect(trunk.kind, MuscleMapValueKind.postureStability);
    expect(trunk.isPostureIndicator, isTrue);
  });

  test('normalizes known legacy heatmap ids without guessing unsided keys', () {
    final regions = buildBodyHeatmapRegionsFromData(const {
      'muscles': [
        {'muscleId': 'triceps_left', 'avgActivation': 52.1, 'sessionCount': 4},
        {
          'muscleId': 'pectoralis_major',
          'avgActivation': 65.3,
          'sessionCount': 4,
        },
      ],
    }, exerciseId: 'pushup');

    final leftTriceps = regions.firstWhere(
      (region) => region.key == 'left_triceps',
    );
    expect(leftTriceps.percent, 52.1);
    expect(leftTriceps.isKnownKey, isTrue);

    final unknownChest = regions.firstWhere(
      (region) => region.key == 'pectoralis_major',
    );
    expect(unknownChest.percent, 65.3);
    expect(unknownChest.viewSide, BodyHeatmapViewSide.both);
    expect(unknownChest.isKnownKey, isFalse);
  });
}

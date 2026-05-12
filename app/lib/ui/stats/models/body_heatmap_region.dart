import '../../../domain/models/muscle_map_schema.dart';

enum BodyHeatmapViewSide { front, back, both, posture }

class BodyHeatmapRegion {
  const BodyHeatmapRegion({
    required this.key,
    required this.displayName,
    required this.viewSide,
    required this.kind,
    required this.percent,
    required this.sessionCount,
    this.isKnownKey = true,
  });

  final String key;
  final String displayName;
  final BodyHeatmapViewSide viewSide;
  final MuscleMapValueKind kind;
  final double? percent;
  final int sessionCount;
  final bool isKnownKey;

  bool get hasData => percent != null;

  bool get isPostureIndicator => viewSide == BodyHeatmapViewSide.posture;
}

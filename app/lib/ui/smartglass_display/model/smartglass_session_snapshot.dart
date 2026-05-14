import 'smartglass_display_models.dart';

enum SmartglassPaceState {
  waiting,
  ready,
  optimal,
  fast,
  slow,
  recovering,
  completed,
}

enum SmartglassPoseState {
  unknown,
  ready,
  holdStill,
  stable,
  imbalance,
  recovery,
  completed,
}

class SmartglassSessionSnapshot {
  const SmartglassSessionSnapshot({
    required this.connectionState,
    required this.sessionPhase,
    required this.workoutLabel,
    required this.currentSet,
    required this.totalSets,
    required this.repCount,
    required this.targetRep,
    required this.paceState,
    required this.poseState,
    required this.activationPercent,
    required this.activationLabel,
    required this.restSeconds,
    required this.calibrationProgress,
    required this.sensorPlacements,
    required this.statusHighlights,
    required this.sourceLabel,
    this.sessionMessage,
    this.detailMessage,
    this.warningMessage,
    this.isMirroredDisplay = true,
  });

  final SmartglassConnectionState connectionState;
  final SmartglassSessionPhase sessionPhase;
  final String workoutLabel;
  final int currentSet;
  final int totalSets;
  final int repCount;
  final int targetRep;
  final SmartglassPaceState paceState;
  final SmartglassPoseState poseState;
  final int activationPercent;
  final String activationLabel;
  final int restSeconds;
  final double calibrationProgress;
  final List<String> sensorPlacements;
  final List<String> statusHighlights;
  final String sourceLabel;
  final String? sessionMessage;
  final String? detailMessage;
  final String? warningMessage;
  final bool isMirroredDisplay;
}

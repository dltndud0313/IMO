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
    this.emgChannelPercents = const [],
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

  /// EMG 1~4 채널별 근활성도(0~100 percent). 분리된 채널은 null.
  /// glass_display_data 메시지에만 실리며, 그 외 메시지에서는 비어 있다(`const []`).
  final List<int?> emgChannelPercents;

  SmartglassSessionSnapshot copyWith({
    SmartglassConnectionState? connectionState,
    SmartglassSessionPhase? sessionPhase,
    String? workoutLabel,
    int? currentSet,
    int? totalSets,
    int? repCount,
    int? targetRep,
    SmartglassPaceState? paceState,
    SmartglassPoseState? poseState,
    int? activationPercent,
    String? activationLabel,
    int? restSeconds,
    double? calibrationProgress,
    List<String>? sensorPlacements,
    List<String>? statusHighlights,
    String? sourceLabel,
    String? sessionMessage,
    String? detailMessage,
    String? warningMessage,
    bool? isMirroredDisplay,
    List<int?>? emgChannelPercents,
  }) {
    return SmartglassSessionSnapshot(
      connectionState: connectionState ?? this.connectionState,
      sessionPhase: sessionPhase ?? this.sessionPhase,
      workoutLabel: workoutLabel ?? this.workoutLabel,
      currentSet: currentSet ?? this.currentSet,
      totalSets: totalSets ?? this.totalSets,
      repCount: repCount ?? this.repCount,
      targetRep: targetRep ?? this.targetRep,
      paceState: paceState ?? this.paceState,
      poseState: poseState ?? this.poseState,
      activationPercent: activationPercent ?? this.activationPercent,
      activationLabel: activationLabel ?? this.activationLabel,
      restSeconds: restSeconds ?? this.restSeconds,
      calibrationProgress: calibrationProgress ?? this.calibrationProgress,
      sensorPlacements: sensorPlacements ?? this.sensorPlacements,
      statusHighlights: statusHighlights ?? this.statusHighlights,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      sessionMessage: sessionMessage ?? this.sessionMessage,
      detailMessage: detailMessage ?? this.detailMessage,
      warningMessage: warningMessage ?? this.warningMessage,
      isMirroredDisplay: isMirroredDisplay ?? this.isMirroredDisplay,
      emgChannelPercents: emgChannelPercents ?? this.emgChannelPercents,
    );
  }
}

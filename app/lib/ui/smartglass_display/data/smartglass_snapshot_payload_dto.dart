import '../model/smartglass_display_models.dart';
import '../model/smartglass_session_snapshot.dart';

class SmartglassSnapshotPayloadDto {
  const SmartglassSnapshotPayloadDto({
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

  factory SmartglassSnapshotPayloadDto.fromJson(Map<String, dynamic> json) {
    return SmartglassSnapshotPayloadDto(
      connectionState: _connectionStateFrom(
        json['connection_state'] as String?,
      ),
      sessionPhase: _sessionPhaseFrom(json['session_phase'] as String?),
      workoutLabel: json['workout_label'] as String? ?? 'Unknown Workout',
      currentSet: _toInt(json['current_set']),
      totalSets: _toInt(json['total_sets']),
      repCount: _toInt(json['rep_count']),
      targetRep: _toInt(json['target_rep']),
      paceState: _paceStateFrom(json['pace_state'] as String?),
      poseState: _poseStateFrom(json['pose_state'] as String?),
      activationPercent: _toInt(json['activation_percent']),
      activationLabel: json['activation_label'] as String? ?? '미측정',
      restSeconds: _toInt(json['rest_seconds']),
      calibrationProgress: _toDouble(json['calibration_progress']),
      sensorPlacements:
          (json['sensor_placements'] as List?)?.cast<String>() ?? const [],
      statusHighlights:
          (json['status_highlights'] as List?)?.cast<String>() ?? const [],
      sourceLabel: json['source_label'] as String? ?? 'Pi Payload',
      sessionMessage: json['session_message'] as String?,
      detailMessage: json['detail_message'] as String?,
      warningMessage: json['warning_message'] as String?,
      isMirroredDisplay: json['is_mirrored_display'] as bool? ?? true,
    );
  }

  SmartglassSessionSnapshot toSnapshot() {
    return SmartglassSessionSnapshot(
      connectionState: connectionState,
      sessionPhase: sessionPhase,
      workoutLabel: workoutLabel,
      currentSet: currentSet,
      totalSets: totalSets,
      repCount: repCount,
      targetRep: targetRep,
      paceState: paceState,
      poseState: poseState,
      activationPercent: activationPercent,
      activationLabel: activationLabel,
      restSeconds: restSeconds,
      calibrationProgress: calibrationProgress,
      sensorPlacements: sensorPlacements,
      statusHighlights: statusHighlights,
      sourceLabel: sourceLabel,
      sessionMessage: sessionMessage,
      detailMessage: detailMessage,
      warningMessage: warningMessage,
      isMirroredDisplay: isMirroredDisplay,
    );
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  static double _toDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static SmartglassConnectionState _connectionStateFrom(String? value) {
    switch (value) {
      case 'connected':
        return SmartglassConnectionState.connected;
      case 'disconnected':
        return SmartglassConnectionState.disconnected;
      case 'connecting':
      default:
        return SmartglassConnectionState.connecting;
    }
  }

  static SmartglassSessionPhase _sessionPhaseFrom(String? value) {
    switch (value) {
      case 'plan_ready':
        return SmartglassSessionPhase.planReady;
      case 'sensor_attachment_pending':
        return SmartglassSessionPhase.sensorAttachmentPending;
      case 'calibration_ready':
        return SmartglassSessionPhase.calibrationReady;
      case 'calibrating':
        return SmartglassSessionPhase.calibrating;
      case 'calibration_success':
        return SmartglassSessionPhase.calibrationSuccess;
      case 'workout_active':
        return SmartglassSessionPhase.workoutActive;
      case 'resting':
        return SmartglassSessionPhase.resting;
      case 'workout_completed':
        return SmartglassSessionPhase.workoutCompleted;
      case 'waiting_workout_selection':
      default:
        return SmartglassSessionPhase.waitingWorkoutSelection;
    }
  }

  static SmartglassPaceState _paceStateFrom(String? value) {
    switch (value) {
      case 'ready':
        return SmartglassPaceState.ready;
      case 'optimal':
        return SmartglassPaceState.optimal;
      case 'fast':
        return SmartglassPaceState.fast;
      case 'slow':
        return SmartglassPaceState.slow;
      case 'recovering':
        return SmartglassPaceState.recovering;
      case 'completed':
        return SmartglassPaceState.completed;
      case 'waiting':
      default:
        return SmartglassPaceState.waiting;
    }
  }

  static SmartglassPoseState _poseStateFrom(String? value) {
    switch (value) {
      case 'ready':
        return SmartglassPoseState.ready;
      case 'hold_still':
        return SmartglassPoseState.holdStill;
      case 'stable':
        return SmartglassPoseState.stable;
      case 'imbalance':
        return SmartglassPoseState.imbalance;
      case 'recovery':
        return SmartglassPoseState.recovery;
      case 'completed':
        return SmartglassPoseState.completed;
      case 'unknown':
      default:
        return SmartglassPoseState.unknown;
    }
  }
}

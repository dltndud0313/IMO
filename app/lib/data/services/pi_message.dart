import '../../domain/models/workout_session.dart';
import '../dto/session_result_dto.dart';

sealed class PiMessage {
  const PiMessage({
    required this.type,
  });

  final String type;
  Map<String, dynamic> get payload;

  Map<String, dynamic> toJson() => {
        'type': type,
        'payload': payload,
      };

  static PiMessage? tryParse(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String || type.isEmpty) {
      return null;
    }

    final rawPayload = json['payload'];
    final payload = rawPayload is Map<String, dynamic>
        ? rawPayload
        : <String, dynamic>{};

    try {
      return switch (type) {
        PiMessageType.connectionStatus =>
          ConnectionStatusMessage.fromPayload(payload),
        PiMessageType.planAck => PlanAckMessage.fromPayload(payload),
        PiMessageType.calibrationStatus =>
          CalibrationStatusMessage.fromPayload(payload),
        PiMessageType.workoutPaused => WorkoutPausedMessage.fromPayload(payload),
        PiMessageType.workoutResumed =>
          WorkoutResumedMessage.fromPayload(payload),
        PiMessageType.workoutStarted =>
          WorkoutStartedMessage.fromPayload(payload),
        PiMessageType.setCompleted => SetCompletedMessage.fromPayload(payload),
        PiMessageType.restStarted => RestStartedMessage.fromPayload(payload),
        PiMessageType.restFinished => RestFinishedMessage.fromPayload(payload),
        PiMessageType.workoutCompleted =>
          WorkoutCompletedMessage.fromPayload(payload),
        PiMessageType.workoutEvent =>
          WorkoutEventMessage.fromPayload(payload),
        PiMessageType.sessionResult =>
          SessionResultMessage.fromPayload(payload),
        PiMessageType.error => PiErrorMessage.fromPayload(payload),
        _ => UnknownPiMessage(type: type, payload: payload),
      };
    } catch (_) {
      return null;
    }
  }
}

abstract final class PiMessageType {
  static const submitWorkoutPlan = 'submit_workout_plan';
  static const sensorsAttached = 'sensors_attached';
  static const startCalibration = 'start_calibration';
  static const emergencyStop = 'emergency_stop';
  static const stopWorkout = 'stop_workout';
  static const pauseWorkout = 'pause_workout';
  static const resumeWorkout = 'resume_workout';

  static const connectionStatus = 'connection_status';
  static const planAck = 'plan_ack';
  static const calibrationStatus = 'calibration_status';
  static const workoutPaused = 'workout_paused';
  static const workoutResumed = 'workout_resumed';
  static const workoutStarted = 'workout_started';
  static const setCompleted = 'set_completed';
  static const restStarted = 'rest_started';
  static const restFinished = 'rest_finished';
  static const workoutCompleted = 'workout_completed';
  static const workoutEvent = 'workout_event';
  static const sessionResult = 'session_result';
  static const error = 'error';
}

class OutgoingPiMessage extends PiMessage {
  const OutgoingPiMessage({
    required super.type,
    required Map<String, dynamic> payload,
  }) : _payload = payload;

  final Map<String, dynamic> _payload;

  @override
  Map<String, dynamic> get payload => _payload;
}

class UnknownPiMessage extends PiMessage {
  const UnknownPiMessage({
    required super.type,
    required Map<String, dynamic> payload,
  }) : _payload = payload;

  final Map<String, dynamic> _payload;

  @override
  Map<String, dynamic> get payload => _payload;
}

class ConnectionStatusMessage extends PiMessage {
  const ConnectionStatusMessage({
    required this.piConnected,
    required this.esp32Connected,
    required this.glassConnected,
  }) : super(type: PiMessageType.connectionStatus);

  final bool piConnected;
  final bool esp32Connected;
  final bool glassConnected;

  factory ConnectionStatusMessage.fromPayload(Map<String, dynamic> payload) {
    return ConnectionStatusMessage(
      piConnected: payload['pi_connected'] as bool? ?? false,
      esp32Connected: payload['esp32_connected'] as bool? ?? false,
      glassConnected: payload['glass_connected'] as bool? ?? false,
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'pi_connected': piConnected,
        'esp32_connected': esp32Connected,
        'glass_connected': glassConnected,
      };
}

class PlanAckMessage extends PiMessage {
  const PlanAckMessage({
    required this.accepted,
    required this.exerciseType,
    required this.setCount,
    this.validationErrors = const [],
  }) : super(type: PiMessageType.planAck);

  final bool accepted;
  final String exerciseType;
  final int setCount;
  final List<String> validationErrors;

  factory PlanAckMessage.fromPayload(Map<String, dynamic> payload) {
    return PlanAckMessage(
      accepted: payload['accepted'] as bool? ?? false,
      exerciseType: payload['exercise_type'] as String? ?? '',
      setCount: payload['set_count'] as int? ?? 0,
      validationErrors:
          (payload['validation_errors'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'accepted': accepted,
        'exercise_type': exerciseType,
        'set_count': setCount,
        if (validationErrors.isNotEmpty) 'validation_errors': validationErrors,
      };
}

class CalibrationStatusMessage extends PiMessage {
  const CalibrationStatusMessage({
    required this.status,
    required this.message,
    this.calibrationSummary,
    this.glassModeActive,
  }) : super(type: PiMessageType.calibrationStatus);

  final String status;
  final String message;
  final CalibrationSummary? calibrationSummary;
  final bool? glassModeActive;

  bool get isStarted => status == 'started';
  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';

  factory CalibrationStatusMessage.fromPayload(Map<String, dynamic> payload) {
    final summary = payload['calibration_summary'];
    return CalibrationStatusMessage(
      status: payload['status'] as String? ?? 'started',
      message: payload['message'] as String? ?? '',
      calibrationSummary: summary is Map<String, dynamic>
          ? CalibrationSummary.fromJson(summary)
          : null,
      glassModeActive: payload['glass_mode_active'] as bool?,
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'status': status,
        'message': message,
        if (calibrationSummary != null)
          'calibration_summary': calibrationSummary!.toJson(),
        if (glassModeActive != null) 'glass_mode_active': glassModeActive,
      };
}

class WorkoutPausedMessage extends PiMessage {
  const WorkoutPausedMessage({
    required this.setIndex,
    required this.currentRep,
    required this.pausedAt,
  }) : super(type: PiMessageType.workoutPaused);

  final int setIndex;
  final int currentRep;
  final String pausedAt;

  factory WorkoutPausedMessage.fromPayload(Map<String, dynamic> payload) {
    return WorkoutPausedMessage(
      setIndex: payload['set_index'] as int? ?? 0,
      currentRep: payload['current_rep'] as int? ?? 0,
      pausedAt: payload['paused_at'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'set_index': setIndex,
        'current_rep': currentRep,
        'paused_at': pausedAt,
      };
}

class WorkoutResumedMessage extends PiMessage {
  const WorkoutResumedMessage({
    required this.setIndex,
    required this.currentRep,
    required this.resumedAt,
  }) : super(type: PiMessageType.workoutResumed);

  final int setIndex;
  final int currentRep;
  final String resumedAt;

  factory WorkoutResumedMessage.fromPayload(Map<String, dynamic> payload) {
    return WorkoutResumedMessage(
      setIndex: payload['set_index'] as int? ?? 0,
      currentRep: payload['current_rep'] as int? ?? 0,
      resumedAt: payload['resumed_at'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'set_index': setIndex,
        'current_rep': currentRep,
        'resumed_at': resumedAt,
      };
}

class WorkoutStartedMessage extends PiMessage {
  const WorkoutStartedMessage({
    required this.exerciseType,
    required this.startedAt,
  }) : super(type: PiMessageType.workoutStarted);

  final String exerciseType;
  final String startedAt;

  factory WorkoutStartedMessage.fromPayload(Map<String, dynamic> payload) {
    return WorkoutStartedMessage(
      exerciseType: payload['exercise_type'] as String? ?? '',
      startedAt: payload['started_at'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'exercise_type': exerciseType,
        'started_at': startedAt,
      };
}

class SetCompletedMessage extends PiMessage {
  const SetCompletedMessage({
    required this.setIndex,
    required this.targetReps,
    required this.actualReps,
    required this.completedAt,
  }) : super(type: PiMessageType.setCompleted);

  final int setIndex;
  final int targetReps;
  final int actualReps;
  final String completedAt;

  factory SetCompletedMessage.fromPayload(Map<String, dynamic> payload) {
    return SetCompletedMessage(
      setIndex: payload['set_index'] as int? ?? 0,
      targetReps: payload['target_reps'] as int? ?? 0,
      actualReps: payload['actual_reps'] as int? ?? 0,
      completedAt: payload['completed_at'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'set_index': setIndex,
        'target_reps': targetReps,
        'actual_reps': actualReps,
        'completed_at': completedAt,
      };
}

class RestStartedMessage extends PiMessage {
  const RestStartedMessage({
    required this.afterSetIndex,
    required this.restSec,
    required this.startedAt,
  }) : super(type: PiMessageType.restStarted);

  final int afterSetIndex;
  final int restSec;
  final String startedAt;

  factory RestStartedMessage.fromPayload(Map<String, dynamic> payload) {
    return RestStartedMessage(
      afterSetIndex: payload['after_set_index'] as int? ?? 0,
      restSec: payload['rest_sec'] as int? ?? 0,
      startedAt: payload['started_at'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'after_set_index': afterSetIndex,
        'rest_sec': restSec,
        'started_at': startedAt,
      };
}

class RestFinishedMessage extends PiMessage {
  const RestFinishedMessage({
    required this.nextSetIndex,
    required this.finishedAt,
  }) : super(type: PiMessageType.restFinished);

  final int nextSetIndex;
  final String finishedAt;

  factory RestFinishedMessage.fromPayload(Map<String, dynamic> payload) {
    return RestFinishedMessage(
      nextSetIndex: payload['next_set_index'] as int? ?? 0,
      finishedAt: payload['finished_at'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'next_set_index': nextSetIndex,
        'finished_at': finishedAt,
      };
}

class WorkoutCompletedMessage extends PiMessage {
  const WorkoutCompletedMessage({
    required this.endedAt,
    required this.status,
    required this.endReason,
  }) : super(type: PiMessageType.workoutCompleted);

  final String endedAt;
  final String status;
  final String endReason;

  factory WorkoutCompletedMessage.fromPayload(Map<String, dynamic> payload) {
    return WorkoutCompletedMessage(
      endedAt: payload['ended_at'] as String? ?? '',
      status: payload['status'] as String? ?? '',
      endReason: payload['end_reason'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'ended_at': endedAt,
        'status': status,
        'end_reason': endReason,
      };
}

class WorkoutEventMessage extends PiMessage {
  const WorkoutEventMessage({
    required this.event,
    required this.exerciseType,
    required this.phase,
    required this.details,
    this.currentSetIndex,
    this.currentRep,
    this.targetRep,
  }) : super(type: PiMessageType.workoutEvent);

  final String event;
  final String exerciseType;
  final String phase;
  final int? currentSetIndex;
  final int? currentRep;
  final int? targetRep;
  final Map<String, dynamic> details;

  factory WorkoutEventMessage.fromPayload(Map<String, dynamic> payload) {
    final details = payload['details'];
    return WorkoutEventMessage(
      event: payload['event'] as String? ?? '',
      exerciseType: payload['exercise_type'] as String? ?? '',
      phase: payload['phase'] as String? ?? '',
      currentSetIndex: payload['current_set_index'] as int?,
      currentRep: payload['current_rep'] as int?,
      targetRep: payload['target_rep'] as int?,
      details: details is Map<String, dynamic> ? details : const {},
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'event': event,
        'exercise_type': exerciseType,
        'phase': phase,
        if (currentSetIndex != null) 'current_set_index': currentSetIndex,
        if (currentRep != null) 'current_rep': currentRep,
        if (targetRep != null) 'target_rep': targetRep,
        if (details.isNotEmpty) 'details': details,
      };
}

class SessionResultMessage extends PiMessage {
  const SessionResultMessage({
    required this.session,
  }) : super(type: PiMessageType.sessionResult);

  final WorkoutSession session;

  factory SessionResultMessage.fromPayload(Map<String, dynamic> payload) {
    final sessionResult = payload['sessionResult'];
    final resultPayload = sessionResult is Map<String, dynamic>
        ? sessionResult
        : payload;

    return SessionResultMessage(
      session: SessionResultDto.fromJson(resultPayload).toDomain(),
    );
  }

  @override
  Map<String, dynamic> get payload => session.toJson();
}

class PiErrorMessage extends PiMessage {
  const PiErrorMessage({
    required this.code,
    required this.message,
  }) : super(type: PiMessageType.error);

  final String code;
  final String message;

  factory PiErrorMessage.fromPayload(Map<String, dynamic> payload) {
    return PiErrorMessage(
      code: payload['code'] as String? ?? 'UNKNOWN',
      message: payload['message'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> get payload => {
        'code': code,
        'message': message,
      };
}

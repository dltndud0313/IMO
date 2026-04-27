import '../../domain/models/workout_session.dart';

// ═══════════════════════════════════════════════════════════
//  Pi → App 메시지 파싱 (1페이지 요약본 기준)
// ═══════════════════════════════════════════════════════════

/// 모든 Pi 수신 메시지의 부모 클래스
sealed class PiMessage {
  final String type;

  const PiMessage({required this.type});

  /// JSON 객체에서 type과 payload를 분석하여 알맞은 구체 클래스 반환
  static PiMessage? tryParse(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) return null;
    
    final payload = json['payload'] as Map<String, dynamic>? ?? {};

    try {
      return switch (type) {
        'connection_status' => ConnectionStatusMsg.fromJson(payload),
        'plan_ack' => PlanAckMsg.fromJson(payload),
        'calibration_status' => CalibrationStatusMsg.fromJson(payload),
        'workout_started' => WorkoutStartedMsg.fromJson(payload),
        'workout_paused' => WorkoutPausedMsg.fromJson(payload),
        'workout_resumed' => WorkoutResumedMsg.fromJson(payload),
        'set_completed' => SetCompletedMsg.fromJson(payload),
        'rest_started' => RestStartedMsg.fromJson(payload),
        'rest_finished' => RestFinishedMsg.fromJson(payload),
        'workout_completed' => WorkoutCompletedMsg.fromJson(payload),
        'session_result' => SessionResultMsg.fromJson(payload),
        'error' => ErrorMsg.fromJson(payload),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }
}

// ─── 4-1. 연결 상태 ───
class ConnectionStatusMsg extends PiMessage {
  final bool piConnected;
  final bool esp32Connected;
  final bool glassConnected;

  const ConnectionStatusMsg({
    required this.piConnected,
    required this.esp32Connected,
    required this.glassConnected,
  }) : super(type: 'connection_status');

  factory ConnectionStatusMsg.fromJson(Map<String, dynamic> data) =>
      ConnectionStatusMsg(
        piConnected: data['pi_connected'] as bool? ?? false,
        esp32Connected: data['esp32_connected'] as bool? ?? false,
        glassConnected: data['glass_connected'] as bool? ?? false,
      );
}

// ─── 4-2. 운동 계획 수신 결과 ───
class PlanAckMsg extends PiMessage {
  final bool accepted;
  final String exerciseType;
  final int setCount;
  final List<String>? validationErrors;

  const PlanAckMsg({
    required this.accepted,
    required this.exerciseType,
    required this.setCount,
    this.validationErrors,
  }) : super(type: 'plan_ack');

  factory PlanAckMsg.fromJson(Map<String, dynamic> data) => PlanAckMsg(
        accepted: data['accepted'] as bool,
        exerciseType: data['exercise_type'] as String,
        setCount: data['set_count'] as int,
        validationErrors: (data['validation_errors'] as List?)?.cast<String>(),
      );
}

// ─── 4-3. 캘리브레이션 상태 ───
class CalibrationStatusMsg extends PiMessage {
  final String status; // started, success, failed
  final String message;
  final CalibrationSummary? calibrationSummary;
  final bool? glassModeActive;

  const CalibrationStatusMsg({
    required this.status,
    required this.message,
    this.calibrationSummary,
    this.glassModeActive,
  }) : super(type: 'calibration_status');

  factory CalibrationStatusMsg.fromJson(Map<String, dynamic> data) =>
      CalibrationStatusMsg(
        status: data['status'] as String,
        message: data['message'] as String,
        calibrationSummary: data['calibration_summary'] != null
            ? CalibrationSummary.fromJson(
                data['calibration_summary'] as Map<String, dynamic>)
            : null,
        glassModeActive: data['glass_mode_active'] as bool?,
      );
}

// ─── 4-4. 운동 시작 ───
class WorkoutStartedMsg extends PiMessage {
  final String exerciseType;
  final String startedAt;

  const WorkoutStartedMsg({
    required this.exerciseType,
    required this.startedAt,
  }) : super(type: 'workout_started');

  factory WorkoutStartedMsg.fromJson(Map<String, dynamic> data) =>
      WorkoutStartedMsg(
        exerciseType: data['exercise_type'] as String,
        startedAt: data['started_at'] as String,
      );
}

// ─── 일시정지 ───
class WorkoutPausedMsg extends PiMessage {
  final int setIndex;
  final int currentRep;
  final String pausedAt;

  const WorkoutPausedMsg({
    required this.setIndex,
    required this.currentRep,
    required this.pausedAt,
  }) : super(type: 'workout_paused');

  factory WorkoutPausedMsg.fromJson(Map<String, dynamic> data) =>
      WorkoutPausedMsg(
        setIndex: data['set_index'] as int,
        currentRep: data['current_rep'] as int,
        pausedAt: data['paused_at'] as String,
      );
}

// ─── 재개 ───
class WorkoutResumedMsg extends PiMessage {
  final int setIndex;
  final int currentRep;
  final String resumedAt;

  const WorkoutResumedMsg({
    required this.setIndex,
    required this.currentRep,
    required this.resumedAt,
  }) : super(type: 'workout_resumed');

  factory WorkoutResumedMsg.fromJson(Map<String, dynamic> data) =>
      WorkoutResumedMsg(
        setIndex: data['set_index'] as int,
        currentRep: data['current_rep'] as int,
        resumedAt: data['resumed_at'] as String,
      );
}

// ─── 4-5. 세트 완료 ───
class SetCompletedMsg extends PiMessage {
  final int setIndex;
  final int targetReps;
  final int actualReps;
  final String completedAt;

  const SetCompletedMsg({
    required this.setIndex,
    required this.targetReps,
    required this.actualReps,
    required this.completedAt,
  }) : super(type: 'set_completed');

  factory SetCompletedMsg.fromJson(Map<String, dynamic> data) =>
      SetCompletedMsg(
        setIndex: data['set_index'] as int,
        targetReps: data['target_reps'] as int,
        actualReps: data['actual_reps'] as int,
        completedAt: data['completed_at'] as String,
      );
}

// ─── 4-6. 휴식 시작 ───
class RestStartedMsg extends PiMessage {
  final int afterSetIndex;
  final int restSec;
  final String startedAt;

  const RestStartedMsg({
    required this.afterSetIndex,
    required this.restSec,
    required this.startedAt,
  }) : super(type: 'rest_started');

  factory RestStartedMsg.fromJson(Map<String, dynamic> data) =>
      RestStartedMsg(
        afterSetIndex: data['after_set_index'] as int,
        restSec: data['rest_sec'] as int,
        startedAt: data['started_at'] as String,
      );
}

// ─── 4-7. 휴식 종료 ───
class RestFinishedMsg extends PiMessage {
  final int nextSetIndex;
  final String finishedAt;

  const RestFinishedMsg({
    required this.nextSetIndex,
    required this.finishedAt,
  }) : super(type: 'rest_finished');

  factory RestFinishedMsg.fromJson(Map<String, dynamic> data) =>
      RestFinishedMsg(
        nextSetIndex: data['next_set_index'] as int,
        finishedAt: data['finished_at'] as String,
      );
}

// ─── 4-8. 운동 종료 ───
class WorkoutCompletedMsg extends PiMessage {
  final String endedAt;
  final String status;
  final String endReason;

  const WorkoutCompletedMsg({
    required this.endedAt,
    required this.status,
    required this.endReason,
  }) : super(type: 'workout_completed');

  factory WorkoutCompletedMsg.fromJson(Map<String, dynamic> data) =>
      WorkoutCompletedMsg(
        endedAt: data['ended_at'] as String,
        status: data['status'] as String,
        endReason: data['end_reason'] as String,
      );
}

// ─── 4-9. 최종 세션 결과 ───
class SessionResultMsg extends PiMessage {
  final WorkoutSession session;

  const SessionResultMsg({
    required this.session,
  }) : super(type: 'session_result');

  factory SessionResultMsg.fromJson(Map<String, dynamic> data) {
    return SessionResultMsg(
      session: WorkoutSession.fromJson(data),
    );
  }
}

// ─── 4-10. 오류 ───
class ErrorMsg extends PiMessage {
  final String code;
  final String message;

  const ErrorMsg({
    required this.code,
    required this.message,
  }) : super(type: 'error');

  factory ErrorMsg.fromJson(Map<String, dynamic> data) => ErrorMsg(
        code: data['code'] as String,
        message: data['message'] as String,
      );
}

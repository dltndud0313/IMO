import '../model/smartglass_display_models.dart';
import '../model/smartglass_session_snapshot.dart';
import 'smartglass_snapshot_payload_dto.dart';

abstract final class SmartglassSnapshotMessageType {
  static const smartglassSnapshot = 'smartglass_snapshot';
  static const glassSessionState = 'glass_session_state';
  static const glassDisplayData = 'glass_display_data';
}

class SmartglassPiSnapshotAdapter {
  const SmartglassPiSnapshotAdapter();

  SmartglassSessionSnapshot? tryParse(Map<String, dynamic> message) {
    final type = message['type'];
    final rawPayload = message['payload'];
    final payload =
        rawPayload is Map<String, dynamic> ? rawPayload : message;

    if (type == SmartglassSnapshotMessageType.smartglassSnapshot ||
        payload.containsKey('session_phase')) {
      return SmartglassSnapshotPayloadDto.fromJson(payload).toSnapshot();
    }

    if (type is! String) return null;

    switch (type) {
      case 'connection_status':
        return _fromConnectionStatus(payload);
      case 'plan_ack':
        return _fromPlanAck(payload);
      case SmartglassSnapshotMessageType.glassSessionState:
        return _fromGlassSessionState(payload);
      case SmartglassSnapshotMessageType.glassDisplayData:
        return _fromGlassDisplayData(payload);
      case 'calibration_status':
        return _fromCalibrationStatus(payload);
      case 'workout_started':
        return _fromWorkoutStarted(payload);
      case 'workout_event':
        return _fromWorkoutEvent(payload);
      case 'rest_started':
        return _fromRestStarted(payload);
      case 'rest_finished':
        return _fromRestFinished(payload);
      case 'workout_completed':
      case 'session_result':
        return _fromWorkoutCompleted(payload);
      default:
        return null;
    }
  }

  SmartglassSessionSnapshot _fromConnectionStatus(Map<String, dynamic> payload) {
    final piConnected = payload['pi_connected'] as bool? ?? false;
    final glassConnected = payload['glass_connected'] as bool? ?? false;

    return SmartglassSessionSnapshot(
      connectionState: glassConnected && piConnected
          ? SmartglassConnectionState.connected
          : SmartglassConnectionState.connecting,
      sessionPhase: SmartglassSessionPhase.waitingWorkoutSelection,
      workoutLabel: '운동 선택 대기',
      currentSet: 0,
      totalSets: 0,
      repCount: 0,
      targetRep: 0,
      paceState: SmartglassPaceState.waiting,
      poseState: SmartglassPoseState.unknown,
      activationPercent: 0,
      activationLabel: '미측정',
      restSeconds: 0,
      calibrationProgress: 0,
      sensorPlacements: const ['센서 위치 안내 대기'],
      statusHighlights: [
        if (piConnected) 'Pi 연결됨' else 'Pi 연결 대기',
        if (glassConnected) '글래스 연결됨' else '글래스 연결 대기',
      ],
      sourceLabel: 'Pi connection_status',
      sessionMessage: '연결 상태만 수신된 초기 단계입니다.',
    );
  }

  SmartglassSessionSnapshot _fromPlanAck(Map<String, dynamic> payload) {
    final accepted = payload['accepted'] as bool? ?? false;
    final setCount = _toInt(payload['set_count']);

    return SmartglassSessionSnapshot(
      connectionState: SmartglassConnectionState.connected,
      sessionPhase: accepted
          ? SmartglassSessionPhase.planReady
          : SmartglassSessionPhase.waitingWorkoutSelection,
      workoutLabel: payload['exercise_type'] as String? ?? 'Workout',
      currentSet: 0,
      totalSets: setCount,
      repCount: 0,
      targetRep: 0,
      paceState: accepted
          ? SmartglassPaceState.ready
          : SmartglassPaceState.waiting,
      poseState: accepted
          ? SmartglassPoseState.ready
          : SmartglassPoseState.unknown,
      activationPercent: 0,
      activationLabel: '측정 전',
      restSeconds: 0,
      calibrationProgress: 0,
      sensorPlacements: const ['센서 부착 단계 준비'],
      statusHighlights: accepted
          ? ['운동 계획 승인', '$setCount세트 준비']
          : ['운동 계획 검증 실패'],
      sourceLabel: 'Pi plan_ack',
      sessionMessage: accepted
          ? '운동 계획이 확정되어 센서 부착 단계로 이동할 수 있습니다.'
          : '운동 계획이 승인되지 않아 운동 선택 단계로 복귀합니다.',
    );
  }

  SmartglassSessionSnapshot _fromCalibrationStatus(
    Map<String, dynamic> payload,
  ) {
    final status = payload['status'] as String? ?? 'started';
    final progress = _extractCalibrationProgress(payload);
    final message = payload['message'] as String?;

    return SmartglassSessionSnapshot(
      connectionState: SmartglassConnectionState.connected,
      sessionPhase: status == 'success'
          ? SmartglassSessionPhase.calibrationSuccess
          : SmartglassSessionPhase.calibrating,
      workoutLabel: payload['exercise_type'] as String? ?? 'Workout',
      currentSet: status == 'success' ? 1 : 0,
      totalSets: _toInt(payload['set_count']),
      repCount: 0,
      targetRep: _toInt(payload['target_rep']),
      paceState: status == 'success'
          ? SmartglassPaceState.ready
          : SmartglassPaceState.ready,
      poseState: status == 'success'
          ? SmartglassPoseState.ready
          : SmartglassPoseState.holdStill,
      activationPercent: 0,
      activationLabel: status == 'success' ? '준비 완료' : '기준값 수집 중',
      restSeconds: 0,
      calibrationProgress: progress,
      sensorPlacements: const ['시작 자세 유지', '몸통 흔들림 최소화'],
      statusHighlights: [
        'calibration_status: $status',
        if (message != null && message.isNotEmpty) message,
      ],
      sourceLabel: 'Pi calibration_status',
      sessionMessage: message,
      warningMessage: status == 'failed' ? '캘리브레이션 재시도 필요' : null,
    );
  }

  SmartglassSessionSnapshot _fromGlassSessionState(
    Map<String, dynamic> payload,
  ) {
    final phase = payload['phase'] as String? ?? 'idle';
    final phaseLabel = payload['phase_label'] as String?;
    final targetRep = _toInt(payload['target_rep']);
    final restSeconds = _toInt(payload['rest_remaining_sec']);
    final sensorsAttached = payload['sensors_attached'] as bool? ?? false;

    return SmartglassSessionSnapshot(
      connectionState: SmartglassConnectionState.connected,
      sessionPhase: _sessionPhaseFromBridgePhase(phase),
      workoutLabel:
          payload['exercise_label'] as String? ??
          payload['exercise_type'] as String? ??
          'Workout',
      currentSet: _toInt(payload['current_set_index']),
      totalSets: _toInt(payload['set_count']),
      repCount: _toInt(payload['current_rep']),
      targetRep: targetRep,
      paceState: _paceFromBridgePhase(phase),
      poseState: _poseFromBridgePhase(phase),
      activationPercent: 0,
      activationLabel: sensorsAttached ? '준비 중' : '센서 확인',
      restSeconds: restSeconds,
      calibrationProgress: 0,
      sensorPlacements: sensorsAttached
          ? const ['센서 부착 확인됨']
          : const ['센서 부착 필요'],
      statusHighlights: [
        if (phaseLabel != null && phaseLabel.isNotEmpty) phaseLabel,
        if (targetRep > 0) '목표 $targetRep회',
      ],
      sourceLabel: 'Pi glass_session_state',
      sessionMessage: phaseLabel,
      detailMessage: phaseLabel,
    );
  }

  SmartglassSessionSnapshot _fromGlassDisplayData(
    Map<String, dynamic> payload,
  ) {
    final phase = payload['phase'] as String? ?? 'idle';
    final currentSpeedLabel = payload['current_speed_label'] as String?;
    final usageTone = payload['usage_tone'] as String?;
    final poseTone = payload['pose_tone'] as String?;
    final usageText = payload['usage_text'] as String?;
    final poseTitle = payload['pose_title'] as String?;
    final poseDetail = payload['pose_detail'] as String?;
    final activationLevel = payload['activation_level'] as String?;
    final targetRep = _toInt(payload['target_rep']);
    final sensorPlacements = _sensorPlacements(payload['sensors']);

    return SmartglassSessionSnapshot(
      connectionState: SmartglassConnectionState.connected,
      sessionPhase: _sessionPhaseFromBridgePhase(phase),
      workoutLabel:
          payload['exercise_label'] as String? ??
          payload['exercise_type'] as String? ??
          'Workout',
      currentSet: _toInt(payload['current_set_index']),
      totalSets: _listLength(payload['target_reps_per_set']),
      repCount: _toInt(payload['current_rep']),
      targetRep: targetRep,
      paceState: _paceFromDisplayData(
        phase: phase,
        currentSpeedLabel: currentSpeedLabel,
        usageTone: usageTone,
      ),
      poseState: _poseFromDisplayData(phase: phase, poseTone: poseTone),
      activationPercent: _toInt(payload['activation_percent']),
      activationLabel: activationLevel?.toUpperCase() ?? 'LOW',
      restSeconds: _toInt(payload['rest_remaining_sec']),
      calibrationProgress: _extractGlassCalibrationProgress(payload),
      sensorPlacements: sensorPlacements,
      statusHighlights: _statusHighlights(
        phaseLabel: payload['phase_label'] as String?,
        currentSpeedLabel: currentSpeedLabel,
        usageText: usageText,
        poseTitle: poseTitle,
      ),
      sourceLabel: 'Pi glass_display_data',
      emgChannelPercents: _emgChannelPercents(payload),
      sessionMessage: usageText,
      detailMessage: poseDetail,
      warningMessage: poseTitle,
    );
  }

  SmartglassSessionSnapshot _fromWorkoutStarted(Map<String, dynamic> payload) {
    return SmartglassSessionSnapshot(
      connectionState: SmartglassConnectionState.connected,
      sessionPhase: SmartglassSessionPhase.workoutActive,
      workoutLabel: payload['exercise_type'] as String? ?? 'Workout',
      currentSet: 1,
      totalSets: _toInt(payload['set_count']),
      repCount: 0,
      targetRep: _toInt(payload['target_rep']),
      paceState: SmartglassPaceState.ready,
      poseState: SmartglassPoseState.ready,
      activationPercent: 0,
      activationLabel: '측정 시작',
      restSeconds: 0,
      calibrationProgress: 0,
      sensorPlacements: const ['실시간 측정 활성'],
      statusHighlights: const ['운동 시작', '실시간 피드백 준비'],
      sourceLabel: 'Pi workout_started',
    );
  }

  SmartglassSessionSnapshot _fromWorkoutEvent(Map<String, dynamic> payload) {
    final details = payload['details'];
    final detailMap = details is Map<String, dynamic> ? details : const {};
    final phase = payload['phase'] as String? ?? '';
    final pace = payload['event'] as String? ?? '';

    return SmartglassSessionSnapshot(
      connectionState: SmartglassConnectionState.connected,
      sessionPhase: phase == 'rest'
          ? SmartglassSessionPhase.resting
          : SmartglassSessionPhase.workoutActive,
      workoutLabel: payload['exercise_type'] as String? ?? 'Workout',
      currentSet: _toInt(payload['current_set_index']),
      totalSets: _toInt(detailMap['total_sets']),
      repCount: _toInt(payload['current_rep']),
      targetRep: _toInt(payload['target_rep']),
      paceState: _paceFromEvent(pace),
      poseState: _poseFromEvent(pace),
      activationPercent: _toInt(detailMap['activation_percent']),
      activationLabel: detailMap['activation_label'] as String? ?? '실시간 분석',
      restSeconds: _toInt(detailMap['rest_seconds']),
      calibrationProgress: 0,
      sensorPlacements:
          (detailMap['sensor_placements'] as List?)?.cast<String>() ??
          const ['실시간 센서 측정 중'],
      statusHighlights:
          (detailMap['status_highlights'] as List?)?.cast<String>() ??
          ['event: $pace', 'phase: $phase'],
      sourceLabel: 'Pi workout_event',
      sessionMessage: detailMap['session_message'] as String?,
      detailMessage: detailMap['detail_message'] as String?,
      warningMessage: detailMap['warning_message'] as String?,
    );
  }

  SmartglassSessionSnapshot _fromRestStarted(Map<String, dynamic> payload) {
    final restSec = _toInt(payload['rest_sec']);

    return SmartglassSessionSnapshot(
      connectionState: SmartglassConnectionState.connected,
      sessionPhase: SmartglassSessionPhase.resting,
      workoutLabel: payload['exercise_type'] as String? ?? 'Workout',
      currentSet: _toInt(payload['after_set_index']),
      totalSets: _toInt(payload['total_sets']),
      repCount: 0,
      targetRep: 0,
      paceState: SmartglassPaceState.recovering,
      poseState: SmartglassPoseState.recovery,
      activationPercent: 0,
      activationLabel: '회복 중',
      restSeconds: restSec,
      calibrationProgress: 0,
      sensorPlacements: const ['다음 세트 시작 자세 준비'],
      statusHighlights: ['휴식 시작', '$restSec초 회복'],
      sourceLabel: 'Pi rest_started',
    );
  }

  SmartglassSessionSnapshot _fromRestFinished(Map<String, dynamic> payload) {
    return SmartglassSessionSnapshot(
      connectionState: SmartglassConnectionState.connected,
      sessionPhase: SmartglassSessionPhase.workoutActive,
      workoutLabel: payload['exercise_type'] as String? ?? 'Workout',
      currentSet: _toInt(payload['next_set_index']),
      totalSets: _toInt(payload['total_sets']),
      repCount: 0,
      targetRep: _toInt(payload['target_rep']),
      paceState: SmartglassPaceState.ready,
      poseState: SmartglassPoseState.ready,
      activationPercent: 0,
      activationLabel: '다음 세트 준비',
      restSeconds: 0,
      calibrationProgress: 0,
      sensorPlacements: const ['다음 세트 시작'],
      statusHighlights: const ['휴식 종료', '다음 세트 진입'],
      sourceLabel: 'Pi rest_finished',
    );
  }

  SmartglassSessionSnapshot _fromWorkoutCompleted(
    Map<String, dynamic> payload,
  ) {
    return SmartglassSessionSnapshot(
      connectionState: SmartglassConnectionState.connected,
      sessionPhase: SmartglassSessionPhase.workoutCompleted,
      workoutLabel: payload['exercise_type'] as String? ?? 'Workout',
      currentSet: _toInt(payload['set_count']),
      totalSets: _toInt(payload['set_count']),
      repCount: _toInt(payload['total_reps']),
      targetRep: _toInt(payload['total_target_reps']),
      paceState: SmartglassPaceState.completed,
      poseState: SmartglassPoseState.completed,
      activationPercent: _toInt(payload['avg_activation_percent']),
      activationLabel: payload['activation_label'] as String? ?? '세션 완료',
      restSeconds: 0,
      calibrationProgress: 0,
      sensorPlacements: const ['센서 제거 가능'],
      statusHighlights: [
        '운동 종료',
        if ((payload['status'] as String?) != null)
          'status: ${payload['status']}',
      ],
      sourceLabel: 'Pi workout_completed',
      sessionMessage: payload['message'] as String?,
    );
  }

  double _extractCalibrationProgress(Map<String, dynamic> payload) {
    final progress = payload['progress'];
    if (progress is num) return progress.toDouble().clamp(0, 1);

    final summary = payload['calibration_summary'];
    if (summary is Map<String, dynamic>) {
      final summaryProgress = summary['progress'];
      if (summaryProgress is num) {
        return summaryProgress.toDouble().clamp(0, 1);
      }
    }

    return (payload['status'] == 'success') ? 1 : 0;
  }

  double _extractGlassCalibrationProgress(Map<String, dynamic> payload) {
    final progress = payload['calibration_progress'];
    if (progress is num) {
      return progress.toDouble().clamp(0, 1);
    }
    return 0;
  }

  /// Pi glass_display_data.emg_channels(EMG 1~4) 파싱.
  /// 각 원소는 {attached, activation_percent} 객체. attached=false 인 채널은
  /// 분리된 것으로 보고 null 로 돌려준다(0% 와 구분). 키가 없으면 빈 리스트.
  List<int?> _emgChannelPercents(Map<String, dynamic> payload) {
    final rawChannels = payload['emg_channels'];
    if (rawChannels is! List) {
      return const [];
    }

    return rawChannels.take(4).map<int?>((entry) {
      if (entry is! Map) {
        return null;
      }
      if (entry['attached'] == false) {
        return null;
      }
      return _toInt(entry['activation_percent']).clamp(0, 100);
    }).toList(growable: false);
  }

  SmartglassSessionPhase _sessionPhaseFromBridgePhase(String phase) {
    switch (phase) {
      case 'ready_for_calibration':
        return SmartglassSessionPhase.sensorAttachmentPending;
      case 'sensors_ready':
        return SmartglassSessionPhase.calibrationReady;
      case 'calibrating':
      case 'calibrating_mvc':
        return SmartglassSessionPhase.calibrating;
      case 'awaiting_workout_start':
        return SmartglassSessionPhase.calibrationSuccess;
      case 'monitoring':
      case 'paused':
        return SmartglassSessionPhase.workoutActive;
      case 'resting':
        return SmartglassSessionPhase.resting;
      case 'completed':
        return SmartglassSessionPhase.workoutCompleted;
      case 'idle':
      default:
        return SmartglassSessionPhase.waitingWorkoutSelection;
    }
  }

  SmartglassPaceState _paceFromBridgePhase(String phase) {
    switch (phase) {
      case 'ready_for_calibration':
      case 'idle':
        return SmartglassPaceState.waiting;
      case 'sensors_ready':
      case 'awaiting_workout_start':
        return SmartglassPaceState.ready;
      case 'resting':
        return SmartglassPaceState.recovering;
      case 'completed':
        return SmartglassPaceState.completed;
      default:
        return SmartglassPaceState.optimal;
    }
  }

  SmartglassPoseState _poseFromBridgePhase(String phase) {
    switch (phase) {
      case 'ready_for_calibration':
      case 'idle':
        return SmartglassPoseState.unknown;
      case 'sensors_ready':
      case 'awaiting_workout_start':
        return SmartglassPoseState.ready;
      case 'calibrating':
      case 'calibrating_mvc':
        return SmartglassPoseState.holdStill;
      case 'resting':
        return SmartglassPoseState.recovery;
      case 'completed':
        return SmartglassPoseState.completed;
      default:
        return SmartglassPoseState.stable;
    }
  }

  SmartglassPaceState _paceFromDisplayData({
    required String phase,
    required String? currentSpeedLabel,
    required String? usageTone,
  }) {
    if (phase == 'resting') {
      return SmartglassPaceState.recovering;
    }
    if (phase == 'awaiting_workout_start' || phase == 'sensors_ready') {
      return SmartglassPaceState.ready;
    }
    if (_containsAny(currentSpeedLabel, const ['빠름', 'fast'])) {
      return SmartglassPaceState.fast;
    }
    if (_containsAny(currentSpeedLabel, const ['느림', 'slow'])) {
      return SmartglassPaceState.slow;
    }
    if (usageTone == 'warn' && _containsAny(currentSpeedLabel, const ['분석', '대기'])) {
      return SmartglassPaceState.waiting;
    }
    return SmartglassPaceState.optimal;
  }

  SmartglassPoseState _poseFromDisplayData({
    required String phase,
    required String? poseTone,
  }) {
    if (phase == 'calibrating' || phase == 'calibrating_mvc') {
      return SmartglassPoseState.holdStill;
    }
    if (phase == 'awaiting_workout_start' || phase == 'sensors_ready') {
      return SmartglassPoseState.ready;
    }
    if (phase == 'resting') {
      return SmartglassPoseState.recovery;
    }
    if (phase == 'completed') {
      return SmartglassPoseState.completed;
    }
    if (poseTone == 'danger') {
      return SmartglassPoseState.imbalance;
    }
    if (poseTone == 'warn') {
      return SmartglassPoseState.holdStill;
    }
    return SmartglassPoseState.stable;
  }

  List<String> _sensorPlacements(Object? sensors) {
    if (sensors is! List) {
      return const ['센서 데이터 수신 중'];
    }

    final placements = <String>[];
    for (final sensor in sensors) {
      if (sensor is! Map) {
        continue;
      }
      final name = sensor['name'];
      final position = sensor['position'];
      if (name is String && position is String) {
        placements.add('$name: $position');
      } else if (position is String) {
        placements.add(position);
      }
    }

    return placements.isEmpty ? const ['센서 데이터 수신 중'] : placements;
  }

  List<String> _statusHighlights({
    required String? phaseLabel,
    required String? currentSpeedLabel,
    required String? usageText,
    required String? poseTitle,
  }) {
    final highlights = <String>[];

    void addIfPresent(String? value) {
      if (value == null || value.isEmpty || highlights.contains(value)) {
        return;
      }
      highlights.add(value);
    }

    addIfPresent(phaseLabel);
    addIfPresent(currentSpeedLabel);
    addIfPresent(usageText);
    addIfPresent(poseTitle);

    return highlights;
  }

  bool _containsAny(String? value, List<String> keywords) {
    if (value == null || value.isEmpty) {
      return false;
    }
    return keywords.any(value.contains);
  }

  int _listLength(Object? value) {
    if (value is List) {
      return value.length;
    }
    return 0;
  }

  SmartglassPaceState _paceFromEvent(String event) {
    switch (event) {
      case 'pace_fast':
      case 'speed_warning':
        return SmartglassPaceState.fast;
      case 'pace_slow':
        return SmartglassPaceState.slow;
      case 'rest':
        return SmartglassPaceState.recovering;
      default:
        return SmartglassPaceState.optimal;
    }
  }

  SmartglassPoseState _poseFromEvent(String event) {
    switch (event) {
      case 'imbalance_warning':
      case 'pose_imbalance':
        return SmartglassPoseState.imbalance;
      case 'hold_still':
        return SmartglassPoseState.holdStill;
      default:
        return SmartglassPoseState.stable;
    }
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('$value') ?? 0;
  }
}

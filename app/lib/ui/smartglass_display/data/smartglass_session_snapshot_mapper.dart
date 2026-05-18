import '../model/smartglass_display_models.dart';
import '../model/smartglass_session_snapshot.dart';

class SmartglassSessionSnapshotMapper {
  const SmartglassSessionSnapshotMapper();

  SmartglassDisplayState map(SmartglassSessionSnapshot snapshot) {
    final tone = _resolveTone(snapshot);
    final phaseLabel = _phaseLabel(snapshot.sessionPhase);
    final paceLabel = _paceLabel(snapshot.paceState);
    final poseTitle = _poseTitle(snapshot);
    final poseDetail = _poseDetail(snapshot);
    final primaryMessage = _primaryMessage(snapshot);
    final secondaryMessage = _secondaryMessage(snapshot);
    final coachCues = _coachCues(snapshot);

    return SmartglassDisplayState(
      connectionState: snapshot.connectionState,
      sessionPhase: snapshot.sessionPhase,
      previewLabel: '실연동',
      phaseLabel: phaseLabel,
      workoutLabel: snapshot.workoutLabel,
      repCount: snapshot.repCount,
      targetRep: snapshot.targetRep,
      currentSet: snapshot.currentSet,
      totalSets: snapshot.totalSets,
      paceLabel: paceLabel,
      activationPercent: snapshot.activationPercent,
      activationLabel: snapshot.activationLabel,
      poseTitle: poseTitle,
      poseDetail: poseDetail,
      primaryMessage: primaryMessage,
      secondaryMessage: secondaryMessage,
      restSeconds: snapshot.restSeconds,
      calibrationProgress: snapshot.calibrationProgress,
      sensorPlacements: snapshot.sensorPlacements,
      statusHighlights: snapshot.statusHighlights,
      coachCues: coachCues,
      readinessLabel: _readinessLabel(snapshot),
      readinessDetail: _readinessDetail(snapshot),
      reconnectHint: _reconnectHint(snapshot),
      sourceLabel: snapshot.sourceLabel,
      tone: tone,
      emgChannelPercents: snapshot.emgChannelPercents,
    );
  }

  SmartglassDisplayTone _resolveTone(SmartglassSessionSnapshot snapshot) {
    if (snapshot.sessionPhase == SmartglassSessionPhase.workoutCompleted ||
        snapshot.sessionPhase == SmartglassSessionPhase.calibrationSuccess) {
      return SmartglassDisplayTone.good;
    }

    if (snapshot.poseState == SmartglassPoseState.imbalance) {
      return SmartglassDisplayTone.danger;
    }

    if (snapshot.paceState == SmartglassPaceState.fast ||
        snapshot.paceState == SmartglassPaceState.slow ||
        snapshot.poseState == SmartglassPoseState.holdStill) {
      return SmartglassDisplayTone.warn;
    }

    if (snapshot.sessionPhase == SmartglassSessionPhase.calibrationReady ||
        snapshot.sessionPhase == SmartglassSessionPhase.workoutActive) {
      return SmartglassDisplayTone.good;
    }

    return SmartglassDisplayTone.neutral;
  }

  String _phaseLabel(SmartglassSessionPhase phase) {
    switch (phase) {
      case SmartglassSessionPhase.waitingWorkoutSelection:
        return '스마트글래스 연결 준비';
      case SmartglassSessionPhase.planReady:
        return '운동 계획 확정';
      case SmartglassSessionPhase.sensorAttachmentPending:
        return '센서 부착 확인';
      case SmartglassSessionPhase.calibrationReady:
        return '캘리브레이션 시작 가능';
      case SmartglassSessionPhase.calibrating:
        return '캘리브레이션 진행 중';
      case SmartglassSessionPhase.calibrationSuccess:
        return '캘리브레이션 완료';
      case SmartglassSessionPhase.workoutActive:
        return '실시간 측정 중';
      case SmartglassSessionPhase.resting:
        return '세트 간 휴식';
      case SmartglassSessionPhase.workoutCompleted:
        return '세션 완료';
    }
  }

  String _paceLabel(SmartglassPaceState paceState) {
    switch (paceState) {
      case SmartglassPaceState.waiting:
        return '분석 대기';
      case SmartglassPaceState.ready:
        return '준비';
      case SmartglassPaceState.optimal:
        return '적정';
      case SmartglassPaceState.fast:
        return '빠름';
      case SmartglassPaceState.slow:
        return '느림';
      case SmartglassPaceState.recovering:
        return '회복 중';
      case SmartglassPaceState.completed:
        return '완료';
    }
  }

  String _poseTitle(SmartglassSessionSnapshot snapshot) {
    if (snapshot.warningMessage != null && snapshot.warningMessage!.isNotEmpty) {
      return snapshot.warningMessage!;
    }

    switch (snapshot.sessionPhase) {
      case SmartglassSessionPhase.waitingWorkoutSelection:
        return '앱에서 운동을 선택하세요';
      case SmartglassSessionPhase.planReady:
        return '세트 계획 확인';
      case SmartglassSessionPhase.sensorAttachmentPending:
        return '센서 부착을 완료하세요';
      case SmartglassSessionPhase.calibrationReady:
        return '시작 자세를 유지하세요';
      case SmartglassSessionPhase.calibrating:
        return '자세를 그대로 유지하세요';
      case SmartglassSessionPhase.calibrationSuccess:
        return '운동을 시작합니다';
      case SmartglassSessionPhase.workoutActive:
        return _activePoseTitle(snapshot.poseState);
      case SmartglassSessionPhase.resting:
        return snapshot.restSeconds > 0
            ? '휴식 ${snapshot.restSeconds}초 남음'
            : '휴식 중';
      case SmartglassSessionPhase.workoutCompleted:
        return '운동이 완료되었습니다';
    }
  }

  String _activePoseTitle(SmartglassPoseState poseState) {
    switch (poseState) {
      case SmartglassPoseState.imbalance:
        return '좌우 밸런스 교정 필요';
      case SmartglassPoseState.stable:
        return '자세 안정적';
      case SmartglassPoseState.holdStill:
        return '불필요한 움직임 주의';
      case SmartglassPoseState.ready:
        return '시작 자세 양호';
      case SmartglassPoseState.recovery:
        return '호흡 회복 중';
      case SmartglassPoseState.completed:
        return '세트 완료';
      case SmartglassPoseState.unknown:
        return '상태 분석 중';
    }
  }

  String _poseDetail(SmartglassSessionSnapshot snapshot) {
    if (snapshot.detailMessage != null && snapshot.detailMessage!.isNotEmpty) {
      return snapshot.detailMessage!;
    }

    switch (snapshot.sessionPhase) {
      case SmartglassSessionPhase.waitingWorkoutSelection:
        return '운동 계획과 센서 부착이 완료되면 스마트글래스가 현재 세션 상태에 맞는 화면을 표시합니다.';
      case SmartglassSessionPhase.planReady:
        return '운동 종목과 세트 수가 확정되었습니다. 센서 부착 단계로 이동할 수 있습니다.';
      case SmartglassSessionPhase.sensorAttachmentPending:
        return '앱에서 센서 부착 완료를 확인한 뒤 캘리브레이션 시작 버튼을 활성화하는 흐름을 전제로 합니다.';
      case SmartglassSessionPhase.calibrationReady:
        return '앱에서 시작 버튼을 누르면 Pi로 신호가 전달되고 스마트글래스는 진행 화면으로 전환됩니다.';
      case SmartglassSessionPhase.calibrating:
        return '센서 기준값을 수집하는 동안 몸통과 팔의 기준 자세를 유지합니다.';
      case SmartglassSessionPhase.calibrationSuccess:
        return '보정이 끝났으므로 첫 세트 측정을 시작할 수 있습니다.';
      case SmartglassSessionPhase.workoutActive:
        return _activePoseDetail(snapshot);
      case SmartglassSessionPhase.resting:
        return '호흡을 정리하고 다음 세트 시작 자세를 미리 맞춰주세요.';
      case SmartglassSessionPhase.workoutCompleted:
        return '모든 세트가 종료되었고 결과 저장 및 요약 단계로 넘어갈 수 있습니다.';
    }
  }

  String _activePoseDetail(SmartglassSessionSnapshot snapshot) {
    switch (snapshot.poseState) {
      case SmartglassPoseState.imbalance:
        return '한쪽 팔 또는 몸통 사용 편차가 감지되었습니다. 좌우 높이와 압력을 다시 맞춰주세요.';
      case SmartglassPoseState.holdStill:
        return '불필요한 흔들림이 섞이고 있습니다. 반동 없이 기준 동작을 유지해 주세요.';
      case SmartglassPoseState.stable:
        return '몸통 정렬과 좌우 팔 밸런스가 안정적으로 유지되고 있습니다.';
      case SmartglassPoseState.ready:
        return '현재 자세를 유지하면 안정적인 반복을 이어갈 수 있습니다.';
      case SmartglassPoseState.recovery:
        return '다음 반복 전 호흡과 중심을 다시 정리해 주세요.';
      case SmartglassPoseState.completed:
        return '현재 세트 반복을 마쳤습니다. 다음 단계로 전환을 준비합니다.';
      case SmartglassPoseState.unknown:
        return '센서 데이터로 현재 동작 상태를 분석하고 있습니다.';
    }
  }

  String _primaryMessage(SmartglassSessionSnapshot snapshot) {
    if (snapshot.sessionMessage != null && snapshot.sessionMessage!.isNotEmpty) {
      return snapshot.sessionMessage!;
    }

    switch (snapshot.sessionPhase) {
      case SmartglassSessionPhase.waitingWorkoutSelection:
        return '연결 직후 현재 세션 상태 스냅샷을 받으면 스마트글래스는 올바른 첫 화면으로 바로 진입할 수 있습니다.';
      case SmartglassSessionPhase.planReady:
        return '스마트글래스는 설정 자체보다 지금 필요한 다음 단계만 크게 보여주는 역할에 집중합니다.';
      case SmartglassSessionPhase.sensorAttachmentPending:
        return '앱은 제어를 담당하고 스마트글래스는 센서 부착 진행과 다음 액션을 짧고 크게 안내합니다.';
      case SmartglassSessionPhase.calibrationReady:
        return '센서 확인이 끝난 세션이면 중간 연결 시에도 이 준비 단계부터 바로 복구하는 것이 맞습니다.';
      case SmartglassSessionPhase.calibrating:
        return '진행률과 자세 고정 안내를 가장 크게 보여주고 나머지 정보는 최소화합니다.';
      case SmartglassSessionPhase.calibrationSuccess:
        return '완료 메시지를 짧게 보여준 뒤 운동 중 화면으로 자연스럽게 전환하면 됩니다.';
      case SmartglassSessionPhase.workoutActive:
        return '현재 순간에 가장 중요한 경고나 코칭만 전면에 배치하고 나머지 정보는 주변으로 보냅니다.';
      case SmartglassSessionPhase.resting:
        return '휴식 중에는 남은 시간과 다음 세트 준비 안내가 속도나 근활성도보다 더 중요합니다.';
      case SmartglassSessionPhase.workoutCompleted:
        return '종료 직후에는 축약된 성공 메시지와 핵심 요약만 보여주고 빠르게 세션 종료를 알립니다.';
    }
  }

  String _secondaryMessage(SmartglassSessionSnapshot snapshot) {
    final mirrorHint = snapshot.isMirroredDisplay
        ? '현재 레이아웃은 스마트글래스 가로 표시를 기준으로 메시지를 좌우 분리합니다.'
        : '현재 레이아웃은 일반 가로 디스플레이 기준으로 메시지를 배치합니다.';

    switch (snapshot.sessionPhase) {
      case SmartglassSessionPhase.calibrating:
        return '$mirrorHint 연결이 중간에 복구되더라도 진행률 스냅샷이 오면 같은 단계에서 이어서 보여줄 수 있습니다.';
      case SmartglassSessionPhase.workoutActive:
        return '$mirrorHint 운동 중 연결 복구 시에는 마지막 세트/반복/경고 스냅샷을 받아 즉시 현재 상태로 돌아와야 합니다.';
      case SmartglassSessionPhase.resting:
        return '$mirrorHint 휴식 화면은 실시간 피드백과 목적이 다르므로 카운트다운을 우선 노출합니다.';
      default:
        return '$mirrorHint 중간 연결이어도 현재 세션 단계 스냅샷만 있으면 대기 화면이 아니라 해당 단계로 바로 복구할 수 있습니다.';
    }
  }

  List<SmartglassCoachCue> _coachCues(SmartglassSessionSnapshot snapshot) {
    switch (snapshot.sessionPhase) {
      case SmartglassSessionPhase.waitingWorkoutSelection:
        return const [
          SmartglassCoachCue(
            label: '운동 선택 필요',
            detail: '앱에서 운동 종목과 세트 계획을 먼저 확정합니다.',
          ),
        ];
      case SmartglassSessionPhase.planReady:
        return const [
          SmartglassCoachCue(
            label: '부착 위치 재확인',
            detail: '센서 부착 완료 전에 좌우 위치와 방향을 한 번 더 확인합니다.',
          ),
        ];
      case SmartglassSessionPhase.sensorAttachmentPending:
        return const [
          SmartglassCoachCue(
            label: '앱 확인 후 시작',
            detail: '캘리브레이션 시작은 앱에서 트리거하고 스마트글래스는 진행만 표시합니다.',
          ),
        ];
      case SmartglassSessionPhase.calibrationReady:
        return const [
          SmartglassCoachCue(
            label: '기준 자세 고정',
            detail: '시작 자세가 흔들리면 기준값이 불안정해질 수 있습니다.',
            tone: SmartglassDisplayTone.good,
          ),
        ];
      case SmartglassSessionPhase.calibrating:
        return const [
          SmartglassCoachCue(
            label: '정지 유지',
            detail: '보정 중에는 불필요한 움직임을 최소화합니다.',
            tone: SmartglassDisplayTone.warn,
          ),
        ];
      case SmartglassSessionPhase.calibrationSuccess:
        return const [
          SmartglassCoachCue(
            label: '첫 1회는 천천히',
            detail: '첫 반복은 기준 동작을 다시 안정적으로 잡는 용도로 천천히 진행합니다.',
            tone: SmartglassDisplayTone.good,
          ),
        ];
      case SmartglassSessionPhase.workoutActive:
        return _activeCoachCues(snapshot);
      case SmartglassSessionPhase.resting:
        return const [
          SmartglassCoachCue(
            label: '호흡 회복',
            detail: '상체 긴장을 낮추고 다음 세트 시작 자세를 다시 맞춥니다.',
          ),
        ];
      case SmartglassSessionPhase.workoutCompleted:
        return const [
          SmartglassCoachCue(
            label: '센서 제거 전 확인',
            detail: '세션 종료 안내가 끝난 뒤 센서를 제거하면 흐름이 더 명확합니다.',
            tone: SmartglassDisplayTone.good,
          ),
        ];
    }
  }

  List<SmartglassCoachCue> _activeCoachCues(
    SmartglassSessionSnapshot snapshot,
  ) {
    if (snapshot.poseState == SmartglassPoseState.imbalance) {
      return const [
        SmartglassCoachCue(
          label: '양손 압력 균등',
          detail: '한쪽으로 기대지 않도록 가슴 중앙을 정면으로 유지합니다.',
          tone: SmartglassDisplayTone.danger,
        ),
      ];
    }

    if (snapshot.paceState == SmartglassPaceState.fast) {
      return const [
        SmartglassCoachCue(
          label: '속도 1단계 낮추기',
          detail: '하강 구간을 조금 더 천천히 가져가면 자세 무너짐을 줄일 수 있습니다.',
          tone: SmartglassDisplayTone.warn,
        ),
      ];
    }

    return const [
      SmartglassCoachCue(
        label: '현재 리듬 유지',
        detail: '반동 없이 같은 깊이와 같은 호흡 패턴을 유지합니다.',
        tone: SmartglassDisplayTone.good,
      ),
    ];
  }

  String _readinessLabel(SmartglassSessionSnapshot snapshot) {
    switch (snapshot.sessionPhase) {
      case SmartglassSessionPhase.waitingWorkoutSelection:
        return 'Snapshot 준비 단계';
      case SmartglassSessionPhase.planReady:
        return '센서 부착 단계로 이동 가능';
      case SmartglassSessionPhase.sensorAttachmentPending:
        return '캘리브레이션 시작 대기';
      case SmartglassSessionPhase.calibrationReady:
        return '캘리브레이션 시작 직전';
      case SmartglassSessionPhase.calibrating:
        return '진행률 기반 복구 가능';
      case SmartglassSessionPhase.calibrationSuccess:
        return '운동 활성 단계 진입';
      case SmartglassSessionPhase.workoutActive:
        return '실시간 피드백 활성';
      case SmartglassSessionPhase.resting:
        return '다음 세트 준비 중';
      case SmartglassSessionPhase.workoutCompleted:
        return '종료 화면 복구 가능';
    }
  }

  String _readinessDetail(SmartglassSessionSnapshot snapshot) {
    switch (snapshot.sessionPhase) {
      case SmartglassSessionPhase.waitingWorkoutSelection:
        return '실제 연동에서는 현재 세션 상태 스냅샷을 기준으로 초기 화면을 선택합니다.';
      case SmartglassSessionPhase.planReady:
        return 'plan_ack 이후 연결돼도 준비 화면 대신 현재 계획 상태를 바로 보여줄 수 있습니다.';
      case SmartglassSessionPhase.sensorAttachmentPending:
        return '센서 부착 단계 스냅샷이 있으면 앱 확인 전 상태를 그대로 복구할 수 있습니다.';
      case SmartglassSessionPhase.calibrationReady:
        return 'calibration_ready 스냅샷만 있어도 시작 직전 안내 화면을 복구할 수 있습니다.';
      case SmartglassSessionPhase.calibrating:
        return 'calibration_status 진행률을 받으면 퍼센트 기반으로 이어서 표시할 수 있습니다.';
      case SmartglassSessionPhase.calibrationSuccess:
        return '보정 완료 후 첫 세트 진입 전 상태를 짧게 보여준 뒤 운동 화면으로 넘길 수 있습니다.';
      case SmartglassSessionPhase.workoutActive:
        return '현재 세트/반복/경고 스냅샷만 유지하면 실시간 피드백 화면은 언제든 다시 복구 가능합니다.';
      case SmartglassSessionPhase.resting:
        return 'rest timer snapshot을 받으면 남은 휴식 시간을 기준으로 바로 복구할 수 있습니다.';
      case SmartglassSessionPhase.workoutCompleted:
        return 'session_result 또는 종료 스냅샷이 있으면 종료 상태를 다시 구성할 수 있습니다.';
    }
  }

  String _reconnectHint(SmartglassSessionSnapshot snapshot) {
    switch (snapshot.sessionPhase) {
      case SmartglassSessionPhase.waitingWorkoutSelection:
        return '연결 직후 현재 단계 스냅샷 필요';
      case SmartglassSessionPhase.planReady:
        return 'plan_ack 이후 연결 복구 가능';
      case SmartglassSessionPhase.sensorAttachmentPending:
        return 'sensor_attach 대기 상태 복구';
      case SmartglassSessionPhase.calibrationReady:
        return 'calibration_ready 상태 복구';
      case SmartglassSessionPhase.calibrating:
        return 'calibration_status 진행률 복구';
      case SmartglassSessionPhase.calibrationSuccess:
        return 'calibration_success 이후 복구';
      case SmartglassSessionPhase.workoutActive:
        return 'live workout snapshot 복구';
      case SmartglassSessionPhase.resting:
        return 'rest timer snapshot 복구';
      case SmartglassSessionPhase.workoutCompleted:
        return 'session_result snapshot 복구';
    }
  }
}

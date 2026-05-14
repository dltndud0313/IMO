import '../model/smartglass_display_models.dart';

class SmartglassPreviewScenarios {
  const SmartglassPreviewScenarios._();

  static SmartglassDisplayState build(SmartglassPreviewScenario scenario) {
    switch (scenario) {
      case SmartglassPreviewScenario.waiting:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connecting,
          sessionPhase: SmartglassSessionPhase.waitingWorkoutSelection,
          previewLabel: '대기',
          phaseLabel: '스마트글래스 연결 준비',
          workoutLabel: '운동 선택 대기',
          repCount: 0,
          targetRep: 0,
          currentSet: 0,
          totalSets: 0,
          paceLabel: '분석 대기',
          activationPercent: 0,
          activationLabel: '미측정',
          poseTitle: '앱에서 운동을 선택하세요',
          poseDetail: '운동 계획과 센서 부착이 완료되면 스마트글래스가 현재 단계에 맞는 화면으로 전환됩니다.',
          primaryMessage: '중간에 스마트글래스를 연결해도 현재 세션 상태 스냅샷을 받으면 이 단계부터 바로 복구할 수 있습니다.',
          secondaryMessage: '실제 Pi 연결 전 단계에서는 preview 시나리오로 준비, 캘리브레이션, 운동, 휴식 흐름을 먼저 검증합니다.',
          restSeconds: 0,
          calibrationProgress: 0,
          sensorPlacements: ['센서 위치 안내 대기'],
          statusHighlights: ['Pi 연결 준비', '운동 미선택', '실시간 피드백 비활성'],
          coachCues: [
            SmartglassCoachCue(
              label: '운동 선택 필요',
              detail: '앱에서 운동 종목과 세트 계획을 먼저 확정합니다.',
            ),
            SmartglassCoachCue(
              label: '스냅샷 복구 가능',
              detail: '연결 직후 현재 단계 스냅샷을 받으면 스마트글래스가 올바른 화면으로 즉시 진입합니다.',
            ),
          ],
          readinessLabel: 'Preview 준비 단계',
          readinessDetail: '실제 센서 데이터 대신 mock 시나리오를 선택해 화면 밀도와 메시지 우선순위를 검증하는 상태입니다.',
          reconnectHint: '연결 직후 현재 단계 스냅샷 필요',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.neutral,
        );
      case SmartglassPreviewScenario.planReady:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.planReady,
          previewLabel: '계획 완료',
          phaseLabel: '운동 계획 확정',
          workoutLabel: 'Push-up',
          repCount: 0,
          targetRep: 12,
          currentSet: 0,
          totalSets: 3,
          paceLabel: '준비',
          activationPercent: 0,
          activationLabel: '측정 전',
          poseTitle: '세트 계획 확인',
          poseDetail: '운동 종목과 세트 수가 확정되었습니다. 이제 센서 부착 단계로 넘어갈 수 있습니다.',
          primaryMessage: '스마트글래스는 복잡한 설정 대신 지금 필요한 다음 단계만 크게 보여줍니다.',
          secondaryMessage: '중간 연결이어도 이미 계획이 확정된 세션이라면 대기 화면이 아니라 이 화면부터 바로 진입해야 합니다.',
          restSeconds: 0,
          calibrationProgress: 0,
          sensorPlacements: ['대흉근 좌/우', '삼두근 좌/우', '좌우 팔 IMU', '몸통 IMU'],
          statusHighlights: ['운동 선택 완료', '3세트 x 12회', '센서 부착 대기'],
          coachCues: [
            SmartglassCoachCue(
              label: '부착 위치 재확인',
              detail: '앱에서 센서 부착 완료를 누르기 전에 부착 위치를 한 번 더 확인합니다.',
            ),
          ],
          readinessLabel: '센서 부착 단계로 이동 가능',
          readinessDetail: '실제 연동 시 plan snapshot만 받아도 스마트글래스는 준비 화면이 아니라 센서 안내 화면으로 바로 전환할 수 있습니다.',
          reconnectHint: 'plan_ack 이후 연결 복구 가능',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.neutral,
        );
      case SmartglassPreviewScenario.sensorAttachment:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.sensorAttachmentPending,
          previewLabel: '센서 부착',
          phaseLabel: '센서 부착 확인',
          workoutLabel: 'Push-up',
          repCount: 0,
          targetRep: 12,
          currentSet: 0,
          totalSets: 3,
          paceLabel: '준비',
          activationPercent: 0,
          activationLabel: '측정 전',
          poseTitle: '센서 부착을 완료하세요',
          poseDetail: '앱에서 부착 완료 확인이 끝나면 캘리브레이션 시작 버튼이 활성화되는 흐름을 전제로 합니다.',
          primaryMessage: '스마트글래스는 센서 부착 진행 상황과 다음 버튼 액션을 짧게 안내하는 역할을 맡습니다.',
          secondaryMessage: '앱과 스마트글래스는 같은 세션 단계를 공유하되, 앱은 제어를 담당하고 스마트글래스는 인지성 높은 표시를 담당합니다.',
          restSeconds: 0,
          calibrationProgress: 0,
          sensorPlacements: ['대흉근 좌/우 부착 확인', '삼두근 좌/우 부착 확인', '좌우 팔 IMU 방향 확인', '몸통 IMU 고정 확인'],
          statusHighlights: ['부착 단계 진행 중', '캘리브레이션 전', '앱 확인 필요'],
          coachCues: [
            SmartglassCoachCue(
              label: '좌우 방향 맞춤',
              detail: '센서 방향이 뒤집히지 않았는지 다시 확인합니다.',
            ),
            SmartglassCoachCue(
              label: '앱 확인 후 시작',
              detail: '캘리브레이션 시작은 앱에서만 트리거하고 스마트글래스는 진행 상태를 표시합니다.',
            ),
          ],
          readinessLabel: '캘리브레이션 시작 대기',
          readinessDetail: '중간 연결 시에도 현재 단계가 센서 부착 중이면 이 화면을 우선 복구하면 됩니다.',
          reconnectHint: 'sensor_attach 대기 상태 복구',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.neutral,
        );
      case SmartglassPreviewScenario.calibrationReady:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.calibrationReady,
          previewLabel: '캘리브 준비',
          phaseLabel: '캘리브레이션 시작 가능',
          workoutLabel: 'Push-up',
          repCount: 0,
          targetRep: 12,
          currentSet: 0,
          totalSets: 3,
          paceLabel: '준비',
          activationPercent: 0,
          activationLabel: '측정 전',
          poseTitle: '시작 자세를 유지하세요',
          poseDetail: '앱에서 시작 버튼을 누르면 Pi로 신호를 보내고, 스마트글래스는 즉시 캘리브레이션 진행 화면으로 전환됩니다.',
          primaryMessage: '중간 연결이어도 이미 센서 확인이 끝난 세션이면 바로 이 단계부터 보여주는 것이 맞습니다.',
          secondaryMessage: '사용자는 시작 버튼을 앱에서 누르고, 스마트글래스에서는 진행 여부와 자세 고정 안내만 보게 됩니다.',
          restSeconds: 0,
          calibrationProgress: 0,
          sensorPlacements: ['시작 자세 유지', '시선 정면 고정', '몸통 흔들림 최소화'],
          statusHighlights: ['센서 확인 완료', '시작 버튼 대기', '캘리브레이션 직전'],
          coachCues: [
            SmartglassCoachCue(
              label: '기준 자세 고정',
              detail: '시작 자세가 흔들리면 기준값이 불안정해질 수 있습니다.',
            ),
          ],
          readinessLabel: '캘리브레이션 시작 직전',
          readinessDetail: 'Pi 연동 시 calibration_ready 스냅샷만 있어도 스마트글래스는 이 준비 화면을 복구할 수 있습니다.',
          reconnectHint: 'calibration_ready 상태 복구',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.good,
        );
      case SmartglassPreviewScenario.calibrating:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.calibrating,
          previewLabel: '캘리브 진행',
          phaseLabel: '캘리브레이션 진행 중',
          workoutLabel: 'Push-up',
          repCount: 0,
          targetRep: 12,
          currentSet: 0,
          totalSets: 3,
          paceLabel: '보정 중',
          activationPercent: 0,
          activationLabel: '기준값 수집 중',
          poseTitle: '자세를 그대로 유지하세요',
          poseDetail: 'Pi가 센서 기준값을 수집하는 동안 몸통과 팔의 기준 자세를 유지합니다.',
          primaryMessage: '스마트글래스는 진행률과 고정 안내를 크게 보여주고, 나머지 정보는 최소화합니다.',
          secondaryMessage: '연결이 중간에 복구되더라도 현재 진행률 스냅샷이 오면 이 화면에서 이어서 보여줄 수 있습니다.',
          restSeconds: 0,
          calibrationProgress: 0.62,
          sensorPlacements: ['자세 고정 유지', '팔 위치 흔들림 최소화', '몸통 중심 유지'],
          statusHighlights: ['Pi calibration 진행 중', '기준값 수집 62%', '움직임 최소화 필요'],
          coachCues: [
            SmartglassCoachCue(
              label: '정지 유지',
              detail: '불필요한 움직임이 있으면 다시 보정이 필요할 수 있습니다.',
              tone: SmartglassDisplayTone.warn,
            ),
          ],
          readinessLabel: '진행률 기반 복구 가능',
          readinessDetail: '중간 연결 시 calibration_status snapshot이 오면 현재 퍼센트부터 이어서 표시하는 구조를 목표로 합니다.',
          reconnectHint: 'calibration_status 진행률 복구',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.warn,
        );
      case SmartglassPreviewScenario.calibrationDone:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.calibrationSuccess,
          previewLabel: '캘리브 완료',
          phaseLabel: '캘리브레이션 완료',
          workoutLabel: 'Push-up',
          repCount: 0,
          targetRep: 12,
          currentSet: 1,
          totalSets: 3,
          paceLabel: '시작 가능',
          activationPercent: 0,
          activationLabel: '준비 완료',
          poseTitle: '운동을 시작합니다',
          poseDetail: '캘리브레이션이 성공적으로 완료되어 첫 세트 측정을 시작할 수 있습니다.',
          primaryMessage: '완료 직후에는 성공 메시지를 짧게 보여준 뒤 운동 중 화면으로 자연스럽게 전환되면 됩니다.',
          secondaryMessage: '중간 연결 시에도 이미 보정이 끝난 세션이라면 다시 보정하지 않고 운동 시작 단계로 바로 복구하는 것이 좋습니다.',
          restSeconds: 0,
          calibrationProgress: 1,
          sensorPlacements: ['첫 세트 시작 자세 준비'],
          statusHighlights: ['보정 완료', '세트 1 시작 직전', '운동 측정 준비'],
          coachCues: [
            SmartglassCoachCue(
              label: '첫 1회는 천천히',
              detail: '첫 반복은 기준 동작을 다시 안정적으로 잡는 용도로 천천히 진행합니다.',
              tone: SmartglassDisplayTone.good,
            ),
          ],
          readinessLabel: '운동 활성 단계 진입',
          readinessDetail: 'Pi에서 calibration_success 이후 start_workout 이벤트가 오면 이 화면을 거쳐 운동 화면으로 진입시키면 됩니다.',
          reconnectHint: 'calibration_success 이후 복구',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.good,
        );
      case SmartglassPreviewScenario.activeBalanced:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.workoutActive,
          previewLabel: '정상',
          phaseLabel: '실시간 측정 중',
          workoutLabel: 'Push-up',
          repCount: 7,
          targetRep: 12,
          currentSet: 2,
          totalSets: 3,
          paceLabel: '적정',
          activationPercent: 68,
          activationLabel: '가슴-삼두 활성 양호',
          poseTitle: '자세 안정적',
          poseDetail: '몸통 정렬과 좌우 팔 밸런스가 안정적으로 유지되고 있습니다.',
          primaryMessage: '현재 세트의 핵심 정보만 크게 보여주는 정상 예시 화면입니다.',
          secondaryMessage: '운동 중 중간 연결이 발생해도 마지막 세트 정보와 현재 피드백 스냅샷을 받으면 즉시 이 화면으로 복구할 수 있습니다.',
          restSeconds: 0,
          calibrationProgress: 0,
          sensorPlacements: ['대흉근 좌/우', '삼두근 좌/우', '좌우 팔 IMU', '몸통 IMU'],
          statusHighlights: ['속도 안정', '좌우 밸런스 양호', '세트 후반 집중 유지'],
          coachCues: [
            SmartglassCoachCue(
              label: '현재 리듬 유지',
              detail: '반동 없이 같은 깊이로 반복을 이어가면 됩니다.',
              tone: SmartglassDisplayTone.good,
            ),
            SmartglassCoachCue(
              label: '호흡 고정',
              detail: '내려갈 때 들이마시고 올라올 때 내쉬는 패턴을 유지합니다.',
            ),
          ],
          readinessLabel: '다음 세트 진입 안정',
          readinessDetail: '현재 상태라면 실시간 Pi 이벤트가 붙어도 화면 우선순위는 그대로 유지해도 됩니다.',
          reconnectHint: 'live workout snapshot 복구',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.good,
        );
      case SmartglassPreviewScenario.activeFast:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.workoutActive,
          previewLabel: '빠름',
          phaseLabel: '실시간 측정 중',
          workoutLabel: 'Push-up',
          repCount: 10,
          targetRep: 12,
          currentSet: 2,
          totalSets: 3,
          paceLabel: '빠름',
          activationPercent: 74,
          activationLabel: '수축 강도 높음',
          poseTitle: '속도 과다 주의',
          poseDetail: '반복 속도가 빨라지고 있어 반동이 섞이지 않는지 확인이 필요합니다.',
          primaryMessage: '속도가 과하게 빠를 때 사용자에게 바로 주의를 주는 예시입니다.',
          secondaryMessage: '좋은 수치가 일부 있어도 현재 가장 중요한 경고를 중앙에 우선 노출하는 구성을 검증합니다.',
          restSeconds: 0,
          calibrationProgress: 0,
          sensorPlacements: ['대흉근 좌/우', '삼두근 좌/우', '좌우 팔 IMU', '몸통 IMU'],
          statusHighlights: ['속도 경고', '마지막 2회 남음', '반동 개입 가능성'],
          coachCues: [
            SmartglassCoachCue(
              label: '속도 1단계 낮추기',
              detail: '하강 구간을 조금 더 천천히 가져가면 자세 무너짐을 줄일 수 있습니다.',
              tone: SmartglassDisplayTone.warn,
            ),
            SmartglassCoachCue(
              label: '깊이 유지 확인',
              detail: '빠르게 반복해도 가동 범위가 줄지 않는지 같이 확인합니다.',
            ),
          ],
          readinessLabel: '실시간 경고 테스트 적합',
          readinessDetail: '향후 Pi가 속도 임계치를 넘겼을 때 이 카드만 빠르게 교체하도록 연결하기 좋은 상태입니다.',
          reconnectHint: 'speed warning snapshot 복구',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.warn,
        );
      case SmartglassPreviewScenario.activeImbalance:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.workoutActive,
          previewLabel: '불균형',
          phaseLabel: '실시간 측정 중',
          workoutLabel: 'Push-up',
          repCount: 5,
          targetRep: 12,
          currentSet: 1,
          totalSets: 3,
          paceLabel: '적정',
          activationPercent: 56,
          activationLabel: '좌우 사용 편차 감지',
          poseTitle: '좌우 팔 높이 차이',
          poseDetail: '한쪽 팔 움직임이 더 크게 잡히고 있습니다. 좌우를 같은 높이로 맞춰보세요.',
          primaryMessage: '불균형과 자세 경고가 중앙에 더 강하게 노출되는 예시입니다.',
          secondaryMessage: '숫자보다 교정 메시지가 먼저 보이도록 해서 스마트글래스 화면의 역할을 분명하게 합니다.',
          restSeconds: 0,
          calibrationProgress: 0,
          sensorPlacements: ['대흉근 좌/우', '삼두근 좌/우', '좌우 팔 IMU', '몸통 IMU'],
          statusHighlights: ['좌우 편차 감지', '몸통 회전 가능성', '폼 교정 우선'],
          coachCues: [
            SmartglassCoachCue(
              label: '양손 압력 균등',
              detail: '한쪽으로 기대지 않도록 가슴 중앙을 바닥 정면으로 유지합니다.',
              tone: SmartglassDisplayTone.danger,
            ),
            SmartglassCoachCue(
              label: '팔꿈치 경로 정렬',
              detail: '좌우 팔꿈치가 비슷한 각도로 움직이는지 확인해 주세요.',
            ),
          ],
          readinessLabel: '자세 교정 시나리오',
          readinessDetail: '실제 Pi에서 imbalance 이벤트가 들어오면 이 영역만 교체해도 교정 피드백 흐름을 유지할 수 있습니다.',
          reconnectHint: 'imbalance warning snapshot 복구',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.danger,
        );
      case SmartglassPreviewScenario.resting:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.resting,
          previewLabel: '휴식',
          phaseLabel: '세트 간 휴식',
          workoutLabel: 'Push-up',
          repCount: 12,
          targetRep: 12,
          currentSet: 2,
          totalSets: 3,
          paceLabel: '적정',
          activationPercent: 18,
          activationLabel: '회복 중',
          poseTitle: '휴식 28초 남음',
          poseDetail: '호흡을 정리하고 다음 세트 시작 자세를 미리 맞춰주세요.',
          primaryMessage: '휴식 중에는 남은 시간과 다음 세트 준비 안내를 우선으로 보여줍니다.',
          secondaryMessage: '운동 중 피드백과 휴식 피드백은 목적이 다르므로, 화면 메시지도 별도로 설계합니다.',
          restSeconds: 28,
          calibrationProgress: 0,
          sensorPlacements: ['다음 세트 시작 자세 준비'],
          statusHighlights: ['심박 안정화 구간', '다음 세트 1회차 준비', '호흡 회복 우선'],
          coachCues: [
            SmartglassCoachCue(
              label: '어깨 힘 빼기',
              detail: '상부 승모 긴장을 낮추고 다음 세트 시작 자세를 준비합니다.',
            ),
            SmartglassCoachCue(
              label: '손 위치 재정렬',
              detail: '손 너비와 몸통 중심을 다시 맞추면 다음 세트 균형 유지에 도움이 됩니다.',
              tone: SmartglassDisplayTone.good,
            ),
          ],
          readinessLabel: '다음 세트 준비 중',
          readinessDetail: '휴식 구간에서는 실시간 수치보다 카운트다운과 준비 안내가 더 중요합니다.',
          reconnectHint: 'rest timer snapshot 복구',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.neutral,
        );
      case SmartglassPreviewScenario.workoutCompleted:
        return const SmartglassDisplayState(
          connectionState: SmartglassConnectionState.connected,
          sessionPhase: SmartglassSessionPhase.workoutCompleted,
          previewLabel: '운동 종료',
          phaseLabel: '세션 완료',
          workoutLabel: 'Push-up',
          repCount: 36,
          targetRep: 36,
          currentSet: 3,
          totalSets: 3,
          paceLabel: '완료',
          activationPercent: 64,
          activationLabel: '세션 평균 양호',
          poseTitle: '운동이 완료되었습니다',
          poseDetail: '모든 세트가 종료되었고, 결과 저장 및 요약 단계로 넘어갈 수 있습니다.',
          primaryMessage: '스마트글래스는 종료 직후 축약된 성공 메시지와 핵심 요약만 보여주고 빠르게 종료 상태를 알립니다.',
          secondaryMessage: '중간 연결이어도 이미 운동이 끝난 세션이면 실시간 측정 화면으로 돌아가지 않고 종료 화면을 복구하는 것이 맞습니다.',
          restSeconds: 0,
          calibrationProgress: 0,
          sensorPlacements: ['센서 제거 가능', '세션 결과 동기화 대기'],
          statusHighlights: ['총 36회 완료', '3세트 종료', '결과 저장 대기'],
          coachCues: [
            SmartglassCoachCue(
              label: '센서 제거 전 확인',
              detail: '결과 저장 안내가 끝난 뒤 센서를 제거하면 세션 종료 흐름이 더 명확합니다.',
              tone: SmartglassDisplayTone.good,
            ),
          ],
          readinessLabel: '종료 화면 복구 가능',
          readinessDetail: 'session_result 스냅샷이 있으면 스마트글래스는 종료 후에도 마지막 상태를 재구성할 수 있습니다.',
          reconnectHint: 'session_result snapshot 복구',
          sourceLabel: 'Preview Snapshot',
          tone: SmartglassDisplayTone.good,
        );
    }
  }

  static String labelOf(SmartglassPreviewScenario scenario) {
    switch (scenario) {
      case SmartglassPreviewScenario.waiting:
        return '대기';
      case SmartglassPreviewScenario.planReady:
        return '계획 완료';
      case SmartglassPreviewScenario.sensorAttachment:
        return '센서 부착';
      case SmartglassPreviewScenario.calibrationReady:
        return '캘리브 준비';
      case SmartglassPreviewScenario.calibrating:
        return '캘리브 진행';
      case SmartglassPreviewScenario.calibrationDone:
        return '캘리브 완료';
      case SmartglassPreviewScenario.activeBalanced:
        return '정상';
      case SmartglassPreviewScenario.activeFast:
        return '빠름';
      case SmartglassPreviewScenario.activeImbalance:
        return '불균형';
      case SmartglassPreviewScenario.resting:
        return '휴식';
      case SmartglassPreviewScenario.workoutCompleted:
        return '운동 종료';
    }
  }
}

# 스마트글래스 실시간 표시 Pi 메시지 계약

작성일: 2026-05-14

## 1. 문서 목적

이 문서는 현재 앱 구조와 `smartglass_display` feature 방향을 유지하면서,
Pi가 어떤 메시지를 보내야 스마트글래스 표시를 안정적으로 구성할 수 있는지 고정하기 위한 계약 문서이다.

핵심 원칙은 다음과 같다.

- 센서 원본 해석 책임은 ESP32/앱이 아니라 Raspberry Pi에 둔다.
- 앱은 Pi가 보낸 해석 결과를 수신하고 제어/저장/상태 표시를 담당한다.
- 스마트글래스는 Pi가 해석한 현재 운동 상태를 큰 정보, 짧은 문구, 빠른 경고 중심으로 재배치한다.
- 기존 `pi_message.dart` 의 메시지 타입은 최대한 유지한다.
- 스마트글래스 때문에 기존 제어 메시지 구조를 뒤엎지 않는다.

## 2. 전체 연결 기준

현재 기준의 전체 흐름은 다음으로 본다.

```text
EMG 4개 + IMU 3개
-> ESP32
-> Raspberry Pi
-> Pi 분석 결과
-> App / Smartglass Display
```

중요한 점:

- 앱은 센서 원본 데이터를 직접 분석하지 않는다.
- Pi가 현재 운동 단계와 해석 결과를 이벤트 형태로 보낸다.
- 스마트글래스는 앱 내부 `smartglass_display` feature 가 그 결과를 표시용 state 로 변환해 그린다.

## 3. 기존 메시지 타입 유지 원칙

기존 앱에는 이미 다음 메시지 타입이 정의되어 있다.

- `connection_status`
- `plan_ack`
- `calibration_status`
- `workout_started`
- `workout_paused`
- `workout_resumed`
- `set_completed`
- `rest_started`
- `rest_finished`
- `workout_completed`
- `workout_event`
- `session_result`

이 중 스마트글래스 실시간 표시에 직접 중요한 타입은 다음이다.

- `connection_status`
- `plan_ack`
- `calibration_status`
- `workout_started`
- `workout_event`
- `rest_started`
- `rest_finished`
- `workout_completed`
- `session_result`

## 4. 권장 방향

기존 방향과 가장 잘 맞는 방식은 다음이다.

### 4.1 우선 사용

기존 메시지 타입 유지:

- 준비/연결 상태는 `connection_status`
- 운동 계획 승인 상태는 `plan_ack`
- 캘리브레이션 상태는 `calibration_status`
- 운동 시작은 `workout_started`
- 세트 사이 휴식은 `rest_started`, `rest_finished`
- 운동 종료는 `workout_completed`, `session_result`

### 4.2 실시간 표시 핵심

실시간 자세/속도/근활성도 경고는 `workout_event` 로 보낸다.

즉 스마트글래스용 신규 프로토콜을 전면 도입하기보다,
기존 `workout_event` 의 `details` 를 확장해 스마트글래스에 필요한 해석 결과를 포함하는 방식이 가장 안전하다.

### 4.3 선택 확장

필요하면 별도 `smartglass_snapshot` 을 추가할 수 있다.

다만 우선순위는 다음이다.

1. 기존 타입으로 해결 가능한지 먼저 본다.
2. 중간 연결 복구나 현재 상태 전체 스냅샷이 꼭 필요할 때만 `smartglass_snapshot` 을 추가한다.

## 5. 스마트글래스가 필요로 하는 최소 상태

스마트글래스 표시를 위해 Pi가 최종적으로 표현해줘야 하는 상태는 다음이다.

- 현재 연결 상태
- 현재 세션 단계
- 운동 종목
- 현재 세트 / 총 세트
- 현재 반복 / 목표 반복
- 현재 속도 상태
- 현재 자세 상태
- 근활성도 요약
- 휴식 남은 시간
- 캘리브레이션 진행률
- 중앙 경고 문구 또는 핵심 메시지
- 짧은 상태 요약 리스트

앱 내부 `smartglass_display` 는 이를 다음 상태로 매핑한다.

```text
waitingWorkoutSelection
planReady
sensorAttachmentPending
calibrationReady
calibrating
calibrationSuccess
workoutActive
resting
workoutCompleted
```

## 6. 메시지별 권장 payload

### 6.1 `connection_status`

기존 구조 유지:

```json
{
  "type": "connection_status",
  "payload": {
    "pi_connected": true,
    "esp32_connected": true,
    "glass_connected": true
  }
}
```

용도:

- 스마트글래스 연결 가능 여부 표시
- 시스템 준비 전 상태 표시

### 6.2 `plan_ack`

기존 구조 유지:

```json
{
  "type": "plan_ack",
  "payload": {
    "accepted": true,
    "exercise_type": "Push-up",
    "set_count": 3,
    "validation_errors": []
  }
}
```

용도:

- 운동 계획 확정
- 스마트글래스 준비 단계 진입

### 6.3 `calibration_status`

기존 구조 유지 + `progress` 권장:

```json
{
  "type": "calibration_status",
  "payload": {
    "status": "started",
    "message": "기준값 수집 중",
    "exercise_type": "Push-up",
    "set_count": 3,
    "target_rep": 12,
    "progress": 0.62,
    "glass_mode_active": true
  }
}
```

권장 필드:

- `status`: `started | success | failed`
- `message`
- `progress`: `0.0 ~ 1.0`
- `exercise_type`
- `set_count`
- `target_rep`
- `glass_mode_active`

용도:

- 캘리브레이션 진행률 표시
- 중간 연결 시 진행률 복구

### 6.4 `workout_started`

기존 구조 유지 + 있으면 좋은 필드:

```json
{
  "type": "workout_started",
  "payload": {
    "exercise_type": "Push-up",
    "started_at": "2026-05-14T10:00:00Z",
    "set_count": 3,
    "target_rep": 12
  }
}
```

용도:

- 운동 시작 화면 진입

### 6.5 `workout_event`

스마트글래스 실시간 표시의 핵심 메시지.

권장 구조:

```json
{
  "type": "workout_event",
  "payload": {
    "event": "speed_warning",
    "exercise_type": "Push-up",
    "phase": "active",
    "current_set_index": 2,
    "current_rep": 9,
    "target_rep": 12,
    "details": {
      "total_sets": 3,
      "activation_percent": 74,
      "activation_label": "수축 강도 높음",
      "pace_state": "fast",
      "pose_state": "stable",
      "warning_message": "속도 과다 주의",
      "detail_message": "반복 속도가 빨라지고 있어 반동이 섞이지 않는지 확인이 필요합니다.",
      "session_message": "현재 순간의 핵심 경고를 우선 표시합니다.",
      "status_highlights": [
        "속도 경고",
        "마지막 3회 남음"
      ],
      "sensor_placements": [
        "대흉근 좌/우",
        "삼두근 좌/우",
        "좌우 팔 IMU",
        "몸통 IMU"
      ]
    }
  }
}
```

`details` 안에서 스마트글래스용으로 권장하는 필드는 다음이다.

- `total_sets`
- `activation_percent`
- `activation_label`
- `pace_state`
  - `waiting | ready | optimal | fast | slow | recovering | completed`
- `pose_state`
  - `unknown | ready | hold_still | stable | imbalance | recovery | completed`
- `warning_message`
- `detail_message`
- `session_message`
- `status_highlights`
- `sensor_placements`
- `rest_seconds` 필요 시 포함

중요:

- `event` 는 기존 이벤트명 유지 가능
- 다만 스마트글래스 표시 안정성을 위해 `details.pace_state`, `details.pose_state` 를 함께 넣는 것을 권장한다
- 즉 이벤트명만 보고 추론하지 말고, 해석 결과 상태도 같이 보내는 것이 좋다

### 6.6 `rest_started`

기존 구조 유지:

```json
{
  "type": "rest_started",
  "payload": {
    "exercise_type": "Push-up",
    "after_set_index": 1,
    "rest_sec": 30,
    "total_sets": 3
  }
}
```

용도:

- 스마트글래스 휴식 화면 진입

### 6.7 `rest_finished`

기존 구조 유지:

```json
{
  "type": "rest_finished",
  "payload": {
    "exercise_type": "Push-up",
    "next_set_index": 2,
    "target_rep": 12,
    "total_sets": 3
  }
}
```

용도:

- 다음 세트 준비/운동 화면 복귀

### 6.8 `workout_completed`

기존 구조 유지 + 요약 필드 권장:

```json
{
  "type": "workout_completed",
  "payload": {
    "exercise_type": "Push-up",
    "ended_at": "2026-05-14T10:18:00Z",
    "status": "completed",
    "end_reason": "normal",
    "set_count": 3,
    "total_reps": 36,
    "total_target_reps": 36,
    "avg_activation_percent": 66,
    "activation_label": "세션 평균 양호",
    "message": "모든 세트가 완료되었습니다."
  }
}
```

용도:

- 스마트글래스 종료 안내

### 6.9 `session_result`

기존 구조 유지.

이 메시지는 결과 저장과 상세 결과 화면의 기준 payload 이다.

스마트글래스에서는 실시간 표시보다 종료 후 복구/최종 요약 용도로만 쓰는 것을 권장한다.

## 7. `smartglass_snapshot` 은 언제 쓰는가

별도 스냅샷 메시지는 다음 조건에서만 추가한다.

- 스마트글래스가 중간에 켜져도 현재 상태를 즉시 복구해야 한다
- 기존 이벤트들만으로는 “현재 최신 상태”를 재구성하기 어렵다
- Pi가 이벤트 스트림과 별개로 “현재 상태 전체”를 즉시 줄 수 있다

권장 예시:

```json
{
  "type": "smartglass_snapshot",
  "payload": {
    "connection_state": "connected",
    "session_phase": "workout_active",
    "workout_label": "Push-up",
    "current_set": 2,
    "total_sets": 3,
    "rep_count": 7,
    "target_rep": 12,
    "pace_state": "optimal",
    "pose_state": "stable",
    "activation_percent": 68,
    "activation_label": "가슴-삼두 활성 양호",
    "rest_seconds": 0,
    "calibration_progress": 0,
    "status_highlights": [
      "속도 안정",
      "좌우 밸런스 양호"
    ],
    "sensor_placements": [
      "대흉근 좌/우",
      "삼두근 좌/우",
      "좌우 팔 IMU",
      "몸통 IMU"
    ],
    "warning_message": "",
    "detail_message": "몸통 정렬과 좌우 팔 밸런스가 안정적으로 유지되고 있습니다.",
    "session_message": "현재 세트의 핵심 정보만 크게 보여줍니다.",
    "source_label": "Pi snapshot",
    "is_mirrored_display": true
  }
}
```

현재 앱의 `smartglass_display` 는 이 형식도 수용 가능하게 준비되어 있다.

## 8. 최종 권장안

기존 방향과 가장 잘 맞는 최종안은 다음이다.

1. 기존 Pi 메시지 타입은 유지한다.
2. 스마트글래스 실시간 표시용 핵심은 `workout_event.details` 확장으로 해결한다.
3. `calibration_status` 에는 `progress` 를 추가한다.
4. `workout_completed` 에는 요약 필드를 조금 더 넣는다.
5. 중간 연결 복구가 꼭 필요하면 그때 `smartglass_snapshot` 을 추가한다.

즉 현재 프로젝트 기준의 우선순위는 다음과 같다.

```text
기존 메시지 유지
-> details 확장
-> 스마트글래스 표시 안정화
-> 필요 시 snapshot 추가
```

## 9. 앱 내부 수용 경로

현재 `smartglass_display` 는 아래 두 경로를 수용할 준비가 되어 있다.

```text
Pi 기존 메시지
-> SmartglassPiSnapshotAdapter
-> SmartglassSessionSnapshot
-> SmartglassSessionSnapshotMapper
-> SmartglassDisplayState
-> UI
```

또는

```text
Pi smartglass_snapshot
-> SmartglassSnapshotPayloadDto
-> SmartglassSessionSnapshot
-> SmartglassSessionSnapshotMapper
-> SmartglassDisplayState
-> UI
```

따라서 Pi 쪽에서는 우선 `workout_event.details` 확장을 목표로 맞추면 된다.

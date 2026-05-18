# 앱 muscle_map 스키마 초안

## 1. 목적

이 문서는 Pi가 운동 종료 후 앱으로 보내는 `session_result.payload.muscle_map`을 앱에서 해석하기 위한 기준이다.

기존 WebSocket 공통 규약인 `type + payload`는 변경하지 않는다.

여기서 정하는 것은 `payload.muscle_map` 안의 항목 이름과 값 해석 기준이다.

예:

```json
{
  "type": "session_result",
  "payload": {
    "exercise_type": "pushup",
    "muscle_map": {
      "left_chest": 68,
      "right_chest": 64,
      "left_triceps": 52,
      "right_triceps": 55,
      "trunk": 72
    }
  }
}
```

## 2. 공통 원칙

- 스케일 계약(2026-05-18 통일): `muscle_map` 값은 Pi·앱·백엔드·DB·응답 전 구간 `0~100` percent 다.
- Pi가 `_build_muscle_map_locked`에서 0~1 비율을 `*100`해 percent 로 보내고, 백엔드는 그대로 통과시킨다.
- 앱은 받은 값을 추가 스케일 변환 없이 그대로 표시한다(표시 직전 `0~100` clamp 만 한다).
- Pi는 원본 EMG/IMU 값을 캘리브레이션 기준으로 보정한 뒤 `0~100` percent 요약값으로 변환해 보낸다.
- 단, 이 값이 세션 평균 활성도인지, 최대 활성도인지, 캘리브레이션/MVC 대비 비율인지는 아직 미확정이다.
- 앱은 원본 센서 데이터를 계산하지 않고, 전달받은 값을 표시명/상태/색상으로 변환한다.
- 앱은 알 수 없는 key가 와도 실패하지 않고, 해당 key를 원문 그대로 보존하거나 기타 항목으로 표시한다.
- `trunk`는 근육 활성도가 아니라 몸통 안정성/자세 보정 점수로 해석한다.
- 이 스키마는 실시간 스트림이 아니라 운동 종료 후 `session_result` 해석 기준이다.

## 3. key 네이밍 규칙

- `muscle_map` key는 앱/Pi/서버가 공통으로 사용하는 영문 snake_case를 기준으로 한다.
- 좌우가 있는 근육은 `left_`, `right_` 접두사를 사용한다.
- 근육명은 앱 표시명과 분리하고, key에는 영문 대표 근육명을 사용한다.
- 같은 근육이라도 운동별 역할이 다를 수 있으므로, 허용 key는 `exercise_type`별로 제한한다.
- `trunk`는 좌우 접두사를 쓰지 않고, IMU3 기반 몸통 안정성 key로 고정한다.
- 앱 화면에서는 key를 그대로 노출하지 않고 한국어 표시명으로 변환한다.

예:

| key | 표시명 |
| --- | --- |
| `left_chest` | 왼쪽 대흉근 |
| `right_biceps` | 오른쪽 이두근 |
| `left_upper_trapezius` | 왼쪽 상부 승모근 |
| `trunk` | 몸통 안정성 |

## 4. 상태 분류 기준

### 4-1. 근육 활성도 key

| 값 범위 | 상태 | 의미 |
| --- | --- | --- |
| 0 | inactive | 측정값 없음 또는 비활성 |
| 1~39 | low | 낮음 |
| 40~69 | normal | 보통 |
| 70~89 | high | 높음 |
| 90~100 | danger | 과활성 또는 보상 위험 |

### 4-2. 자세/몸통 안정성 key

`trunk`는 높은 값일수록 안정적인 상태로 해석한다.

| 값 범위 | 상태 | 의미 |
| --- | --- | --- |
| 0 | inactive | 측정값 없음 |
| 1~29 | danger | 몸통 흔들림/반동 위험 |
| 30~49 | low | 안정성 낮음 |
| 50~74 | normal | 보통 |
| 75~100 | high | 안정적 |

## 5. 운동별 허용 key

### 5-1. Push-up

`exercise_type`: `pushup`

| key | 표시명 | 성격 | 의미 |
| --- | --- | --- | --- |
| `left_chest` | 왼쪽 대흉근 | 근육 활성도 | 왼쪽 주동근 활성도 |
| `right_chest` | 오른쪽 대흉근 | 근육 활성도 | 오른쪽 주동근 활성도 |
| `left_triceps` | 왼쪽 삼두근 | 근육 활성도 | 왼쪽 보조근/보상근 개입 |
| `right_triceps` | 오른쪽 삼두근 | 근육 활성도 | 오른쪽 보조근/보상근 개입 |
| `trunk` | 몸통 안정성 | 자세 안정성 | 상체 정렬, 허리/몸통 흔들림 |

### 5-2. Bicep Curl

`exercise_type`: `bicep_curl`

| key | 표시명 | 성격 | 의미 |
| --- | --- | --- | --- |
| `left_biceps` | 왼쪽 이두근 | 근육 활성도 | 왼쪽 주동근 활성도 |
| `right_biceps` | 오른쪽 이두근 | 근육 활성도 | 오른쪽 주동근 활성도 |
| `left_forearm` | 왼쪽 전완근 | 근육 활성도 | 왼쪽 전완 과개입 확인 |
| `right_forearm` | 오른쪽 전완근 | 근육 활성도 | 오른쪽 전완 과개입 확인 |
| `trunk` | 몸통 안정성 | 자세 안정성 | 몸통 반동, 팔꿈치 축 흔들림 |

### 5-3. Lateral Raise

`exercise_type`: `lateral_raise`

| key | 표시명 | 성격 | 의미 |
| --- | --- | --- | --- |
| `left_lateral_deltoid` | 왼쪽 측면 삼각근 | 근육 활성도 | 왼쪽 주동근 활성도 |
| `right_lateral_deltoid` | 오른쪽 측면 삼각근 | 근육 활성도 | 오른쪽 주동근 활성도 |
| `left_upper_trapezius` | 왼쪽 상부 승모근 | 근육 활성도 | 왼쪽 승모근 보상 여부 |
| `right_upper_trapezius` | 오른쪽 상부 승모근 | 근육 활성도 | 오른쪽 승모근 보상 여부 |
| `trunk` | 몸통 안정성 | 자세 안정성 | 몸통 흔들림, 반동 사용 |

## 6. 좌우 밸런스와의 관계

`muscle_map`은 각 부위별 활성도/안정성 값을 표현한다.

좌우 밸런스는 `muscle_map`의 좌우 key를 비교해서 앱 또는 서버에서 해석할 수 있다.

예:

- `left_chest` vs `right_chest`
- `left_biceps` vs `right_biceps`
- `left_lateral_deltoid` vs `right_lateral_deltoid`

다만 `muscle_map` 자체는 좌우 차이를 계산한 결과가 아니라 원본 부위별 요약값이다.

따라서 최종 결과에서 좌우 밸런스를 별도로 내려줄 경우에는 기존 합의처럼 `balance_summary`를 사용할 수 있다.

```json
{
  "balance_summary": {
    "enabled": true,
    "left_avg": 71,
    "right_avg": 76,
    "difference": 5
  }
}
```

좌우 비교가 불가능한 운동이나 센서 배치에서는 아래처럼 비활성화한다.

```json
{
  "balance_summary": {
    "enabled": false,
    "reason": "no_left_right_pairing"
  }
}
```

## 7. Pi 전달 사항

Pi는 운동 종료 시 `session_result` 메시지를 전송해야 한다.

현재 라즈베리파이 코드에는 `workout_event` 전송은 구현되어 있지만, 최종 `session_result` 생성/전송은 아직 구현되어 있지 않다.

앱은 중간 운동 이벤트는 Pi의 현재 구조에 맞춰 아래 형식을 받을 수 있게 한다.

```json
{
  "type": "workout_event",
  "payload": {
    "event": "workout_completed"
  }
}
```

다만 최종 저장/결과 표시 기준 데이터는 아래처럼 별도의 `session_result`로 받는 것을 기준으로 한다.

```json
{
  "type": "session_result",
  "payload": {
    "exercise_type": "pushup",
    "muscle_map": {
      "left_chest": 68,
      "right_chest": 64,
      "left_triceps": 52,
      "right_triceps": 55,
      "trunk": 72
    }
  }
}
```

## 8. 앱 적용 범위

- `muscle_map` key를 한국어 표시명으로 변환한다.
- 값은 `0~100` percent 로 clamp 하고, 화면에는 추가 변환 없이 그대로 표시한다.
- 근육 활성도와 몸통 안정성은 다른 상태 기준을 사용한다.
- 중간 이벤트는 Pi의 `workout_event.payload.event` 구조를 수신한다.
- 센서부착완료 버튼에서는 Pi 현재 흐름에 맞춰 `sensors_attached` 후 `start_calibration`을 전송한다.

## 9. 이번 작업에서 제외

- 히트맵 UI 구현
- 3D avatar 구현
- Pi의 `session_result` 생성 로직 구현
- 서버 저장 스키마 변경
- 실시간 센서 스트림 표시

# Pi muscle_map 키 정렬 및 데이터 손실 버그 수정

> Pi 담당자용 작업 명세. 앱 와이어링 작업 중 발견된 Pi 코드 이슈 정리.

## 배경

앱 측 SessionResultScreen 와이어링 작업을 진행하면서 Pi의 `_build_muscle_map_locked` 함수가 **실제 부착된 센서 데이터의 일부를 손실시키거나** sensor_guide_screen이 사용자에게 안내하는 부착 부위와 명명이 안 맞는 문제를 발견. 진단 결과 Pi 코드 수정이 필요함.

## 발견된 문제

### 문제 1 ⚠️ — lateral_raise에서 상부 승모근 데이터 완전 손실

**[sensor_guide_screen.dart](../app/lib/ui/workout_setup/widgets/sensor_guide_screen.dart)가 사용자에게 안내하는 EMG 부착 위치 (lateral_raise):**
- EMG 1: 왼쪽 측면 삼각근
- EMG 2: 오른쪽 측면 삼각근
- **EMG 3: 왼쪽 상부 승모근**
- **EMG 4: 오른쪽 상부 승모근**

**[pi_sensor_bridge.py:424](../device/raspberry-pi/pi_sensor_bridge.py#L424) `_build_muscle_map_locked`의 현재 lateral_raise 처리:**
```python
if self._exercise_type == "lateral_raise":
    return {
        "chest": 0.0,
        "left_shoulder": ch1,
        "right_shoulder": ch2,
        "left_triceps": 0.0,    # ← ch3 (상부 승모근) 무시
        "right_triceps": 0.0,   # ← ch4 (상부 승모근) 무시
    }
```

ch3/ch4 데이터가 muscle_map 어디에도 포함되지 않음. 사용자가 승모근에 센서를 부착해도 데이터가 화면/통계 어디서도 보이지 않음.

### 문제 2 — pushup에서 좌/우 대흉근 정보 손실

**sensor_guide_screen 안내:**
- EMG 1: 왼쪽 대흉근
- EMG 2: 오른쪽 대흉근

**현재 Pi 처리:**
```python
"chest": (ch1 + ch2) / 2.0,   # ← 평균 처리, 좌/우 정보 사라짐
```

좌우 밸런스 분석이 pushup에선 불가능해짐.

### 문제 3 — Pi 키와 schema 키 명명 불일치

**`exercise_sensor_mapping.dart` schema (anatomical 명명):**
- `left_chest`, `right_chest`
- `left_lateral_deltoid`, `right_lateral_deltoid`
- `left_upper_trapezius`, `right_upper_trapezius`
- `left_biceps`, `right_biceps`, `left_forearm`, `right_forearm`

**Pi가 실제 송신:**
- `chest` (단일)
- `left_shoulder`, `right_shoulder` (실제로는 lateral deltoid 부위)
- `left_triceps`, `right_triceps` (lateral_raise에선 0으로만 박힘)
- `left_biceps`, `right_biceps`, `left_forearm`, `right_forearm`

## 변경 사항

### 1. `_build_muscle_map_locked` 수정

[pi_sensor_bridge.py:424 근방](../device/raspberry-pi/pi_sensor_bridge.py#L424) — 운동별로 sensor_guide_screen 안내와 schema 키에 맞게:

스케일 계약(2026-05-18 통일): muscle_map 값은 Pi·앱·백엔드·DB·응답 전 구간
`0~100` percent. `_channel_average_locked`는 `0~1` 비율을 돌려주므로 여기서 `*100` 한다.

```python
def _build_muscle_map_locked(self) -> dict[str, float]:
    # 0~1 ratio → 0~100 percent 변환 (스케일 계약).
    ch1 = self._channel_average_locked(0) * 100.0
    ch2 = self._channel_average_locked(1) * 100.0
    ch3 = self._channel_average_locked(2) * 100.0
    ch4 = self._channel_average_locked(3) * 100.0

    if self._exercise_type == "pushup":
        return {
            "left_chest": ch1,
            "right_chest": ch2,
            "left_triceps": ch3,
            "right_triceps": ch4,
        }
    if self._exercise_type == "lateral_raise":
        return {
            "left_lateral_deltoid": ch1,
            "right_lateral_deltoid": ch2,
            "left_upper_trapezius": ch3,
            "right_upper_trapezius": ch4,
        }
    # bicep_curl
    return {
        "left_biceps": ch1,
        "right_biceps": ch2,
        "left_forearm": ch3,
        "right_forearm": ch4,
    }
```

핵심 변화:
- 운동별 4개 채널 모두 캡처 (0으로 박는 키 제거)
- 키 명명을 schema와 정합
- pushup chest를 좌/우 분리 (평균 X)

### 2. `_build_session_result_locked`의 avg 계산도 정렬

[pi_sensor_bridge.py:461 근방](../device/raspberry-pi/pi_sensor_bridge.py#L461):

```python
if self._exercise_type == "pushup":
    avg_target = (muscle_map["left_chest"] + muscle_map["right_chest"]) / 2.0
    avg_assist = (muscle_map["left_triceps"] + muscle_map["right_triceps"]) / 2.0
elif self._exercise_type == "lateral_raise":
    avg_target = (muscle_map["left_lateral_deltoid"] + muscle_map["right_lateral_deltoid"]) / 2.0
    avg_assist = (muscle_map["left_upper_trapezius"] + muscle_map["right_upper_trapezius"]) / 2.0
elif self._exercise_type == "bicep_curl":
    avg_target = (muscle_map["left_biceps"] + muscle_map["right_biceps"]) / 2.0
    avg_assist = (muscle_map["left_forearm"] + muscle_map["right_forearm"]) / 2.0
```

### 3. balance_summary 키 정렬

[pi_sensor_bridge.py:473 근방](../device/raspberry-pi/pi_sensor_bridge.py#L473) — left/right balance 계산도 새 키로:

```python
if self._exercise_type == "lateral_raise":
    left_balance = muscle_map["left_lateral_deltoid"]
    right_balance = muscle_map["right_lateral_deltoid"]
elif self._exercise_type == "bicep_curl":
    left_balance = muscle_map["left_biceps"]
    right_balance = muscle_map["right_biceps"]
elif self._exercise_type == "pushup":
    # 새로 추가 — 좌/우 대흉근 분리되어서 이제 pushup도 balance 가능
    left_balance = muscle_map["left_chest"]
    right_balance = muscle_map["right_chest"]
```

(현재는 pushup에선 balance 계산 안 함. 좌/우 대흉근 분리되니 이제 의미 있음)


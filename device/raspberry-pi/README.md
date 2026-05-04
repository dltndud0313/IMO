# device/raspberry-pi

Raspberry Pi 수신기, 로그 저장, 후속 처리 코드를 두는 폴더입니다.

현재 이 폴더에는 최신 BINARY_V2 수신 확인용 스크립트와
앱 전달용 WebSocket 브리지, 스마트글래스 확인용 HUD UI가 포함되어 있습니다.

- 실행 스크립트:
  - `esp32_serial_receiver.py`
  - `pi_sensor_bridge.py`
  - `ws_control_demo.py`
- UI 자산:
  - `glass-ui/index.html`
- 목적:
  - ESP32 직렬 데이터를 Raspberry Pi에서 받아
  - 프레임 동기화/CRC 검증 후
  - 해석된 센서값을 콘솔에 출력하거나
  - 앱 연결용 WebSocket JSON 메시지로 변환

기존의 `sole_imu_test.py`, `dumydata_imu_test.py` 는 과거 실험용이라
현재 `64 bytes BINARY_V2` 포맷과는 맞지 않을 수 있습니다.

## 먼저 볼 문서 순서

0. `../../docs/esp32_pi_protocol_quick_reference.md`
   - 포맷 차이, 현재 기본값, 구현 기준을 한 번에 보는 요약 문서
1. `../esp32/README.md`
   - 전체 흐름, 현재 기본 포맷, JSON/BINARY 선택 구조
2. `../../shared/protocol/esp32_pi_packet_format.md`
   - **Pi 구현 기준 문서**
   - v2 바이너리 프레임 구조, 상태 코드, 스케일 규칙
3. `../../shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`
   - 초기 JSONL 로그를 읽거나 bring-up 디버깅할 때 참고

## 현재 기준

- ESP32 기본 송신 매체: `USB Serial`
- 포맷 선택 구조:
  - `JSON_V1`
  - `BINARY_V2`
- 현재 펌웨어 기본값: `JSON_V1`
- 실시간 경로 권장값: `BINARY_V2`

즉, Pi 수신기는 두 포맷을 모두 이해하면 가장 좋고, 최소한 현재 bring-up 단계에서는 JSON 로그를 읽을 수 있어야 합니다.

## 바로 확인하는 방법

1. ESP32가 현재 `BINARY_V2` 로 빌드되어 있는지 확인
2. Raspberry Pi에서 포트 확인

```bash
ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

3. 필요 시 `pyserial` 설치

```bash
pip install pyserial
```

4. 수신기 실행

```bash
cd device/raspberry-pi
python3 esp32_serial_receiver.py --port /dev/ttyUSB0
```

포트가 `ttyACM0` 로 잡히면 그 경로로 바꿔 실행합니다.

출력 예:

```text
seq=120    ts=2400     emg=(0.012,0.000,0.000,0.000) imu1_acc=(0.011,0.997,-0.028) imu1_gyro=(0.12,-0.03,0.08) imu2_acc=(0.000,0.000,0.000) imu2_gyro=(0.00,0.00,0.00) imu3_acc=(0.000,0.000,0.000) imu3_gyro=(0.00,0.00,0.00) state=STREAMING flags=0x02 rep_index=None
```

이 단계가 성공하면 다음 단계는:

- 필요한 값만 추려서 내부 Python 객체로 변환
- 소켓/WebSocket/MQTT 중 원하는 경로로 앱 쪽에 전달

## 앱 연결용 WebSocket 브리지

필요 패키지:

```bash
pip install pyserial websockets
```

실행:

```bash
cd device/raspberry-pi
python3 pi_sensor_bridge.py \
  --serial-port /dev/ttyUSB0 \
  --ws-host 0.0.0.0 \
  --ws-port 8765 \
  --ui-host 0.0.0.0 \
  --ui-port 8080
```

앱은 아래 주소로 붙으면 됩니다.

```text
ws://<raspberry-pi-ip>:8765
```

스마트글래스용 HUD 뷰어는 아래 주소로 열면 됩니다.

```text
http://<raspberry-pi-ip>:8080
```

브리지가 보내는 주요 메시지:

- `connection_status`
- `sensor_frame`
- `glass_session_state`
- `glass_display_data`
- `workout_event`
- `error`

`sensor_frame` 예시:

```json
{
  "type": "sensor_frame",
  "payload": {
    "seq": 120,
    "timestamp_ms": 2400,
    "state_code": 1,
    "state": "STREAMING",
    "flags": 2,
    "flag_detail": {
      "is_mock": false,
      "imu_bias_ready": true,
      "motion_detected": false,
      "imu_partial_ready": false
    },
    "rep_index": null,
    "emg": [0.012, 0.0, 0.0, 0.0],
    "imus": [
      {
        "index": 1,
        "accel": [0.011, 0.997, -0.028],
        "gyro": [0.12, -0.03, 0.08]
      }
    ]
  }
}
```

현재 이 브리지는 앱에서 오는 제어 메시지를 우선 로그로만 받고,
센서 스트림을 앱에 보내는 최소 경로에 집중합니다.

지금은 아래 메시지에 반응해 글래스 화면 상태를 바꿉니다.

- `submit_workout_plan`
  - 운동 종류, 세트 수, 목표 횟수를 HUD에 반영
- `sensors_attached`
  - 센서 부착 완료 상태 반영
- `start_calibration`
  - HUD를 캘리브레이션 상태로 전환
- `pause_workout`, `resume_workout`
  - 측정 상태 전환
- `stop_workout`, `emergency_stop`
  - 종료 상태 전환

또한 운동 진행 중에는 아래 `workout_event`가 자동으로 나갑니다.

- `set_completed`
- `rest_started`
- `rest_finished`
- `workout_completed`
- `workout_stopped`
- `emergency_stopped`

## 앱 없이 흐름 테스트하기

브리지와 HUD를 띄운 뒤, 아래 데모 스크립트로 앱 제어 메시지를 흉내낼 수 있습니다.

```bash
cd device/raspberry-pi
python3 ws_control_demo.py --url ws://127.0.0.1:8765 --exercise pushup --flow full
```

이 스크립트는 기본적으로 아래 순서대로 보냅니다.

1. `submit_workout_plan`
2. `sensors_attached`
3. `start_calibration`

추가로 아래 단독 테스트도 가능합니다.

```bash
python3 ws_control_demo.py --url ws://127.0.0.1:8765 --flow pause
python3 ws_control_demo.py --url ws://127.0.0.1:8765 --flow resume
python3 ws_control_demo.py --url ws://127.0.0.1:8765 --flow stop
python3 ws_control_demo.py --url ws://127.0.0.1:8765 --flow emergency
```

운동 종류는 아래 중 하나로 바꿀 수 있습니다.

- `pushup`
- `bicep_curl`
- `lateral_raise`

## 스마트글래스 UI 구성

현재 HUD는 아래 정보를 표시합니다.

- 좌측 상단: 운동 종류
- 우측 상단: 현재 횟수
- 우측 상단 하단: 현재 세트와 휴식 남은 시간
- 좌측 하단: 근육 활성도와 목표 근육 사용 여부
- 중앙: 자세 판단
- 우측 하단: 운동별 센서 부착 위치

운동별 센서 위치는 앱 화면의 가이드 기준과 맞췄습니다.

- `pushup`
  - Chest, Shoulder, Triceps, Upper back
- `bicep_curl`
  - Biceps, Forearm, Shoulder, Wrist
- `lateral_raise`
  - Side deltoid, Upper trapezius, Rear shoulder, Wrist

자세 판단과 목표 근육 사용 여부는 현재 Pi 서버가 `glass_display_data` 메시지로 계산해 전달합니다.
운동별 휴리스틱은 `glass_metrics.py`에 모여 있어서, 실제 센서 로그를 보며 이 파일의 임계값만
조정하면 HUD 전체에 바로 반영됩니다.

또한 ESP32에서 `rep_index`를 주지 않아도, Pi 브리지에서 IMU 움직임과 EMG 활성도를 조합한
임시 rep 추정 로직을 사용해 현재 횟수를 올려볼 수 있게 해두었습니다.

## Pi 쪽 최소 요구사항

### JSON_V1 수신기

- Serial에서 한 줄씩 읽기
- UTF-8 문자열 decode
- JSON parse
- 필수 필드 검증
- 로그 저장/표시

### BINARY_V2 수신기

- Serial에서 byte stream 읽기
- `magic == 0x454D` 찾기
- header(`magic`, `version`, `packet_type`, `payload_len`) 검증
- payload 길이만큼 읽기
- `crc16` 검증
- little-endian unpack
- 상태 코드와 스케일 규칙 적용

## v2 바이너리 구현 체크리스트

- `magic`: `0x454D`
- `version`: `2`
- `packet_type`: `1`
- `payload_len`: `56`
- 전체 프레임 길이: `64 bytes`
- endian: `little-endian`
- `state`: `uint8_t` 코드
- `rep_index == -1` 이면 값 없음
- `emg_ch*`: `0~1000` 스케일 -> `1000.0`으로 나눠 복원
- `acc_*`: `1000` 스케일 -> `1000.0`으로 나눠 복원
- `gyro_*`: `100` 스케일 -> `100.0`으로 나눠 복원

## Python 구현 시작점 예시

바이너리 v2 기준으로는 Python 표준 라이브러리 `struct`만으로 시작할 수 있습니다.

```python
import struct

HEADER_FMT = "<HBBH"
CRC_FMT = "<H"

HEADER_SIZE = struct.calcsize(HEADER_FMT)  # 6
FRAME_SIZE = 64
PAYLOAD_SIZE = 56
```

상태 코드는 아래를 기준으로 매핑합니다.

- `0`: `IDLE`
- `1`: `STREAMING`
- `2`: `ERROR`

## 실무적으로 권장하는 진행 순서

1. 먼저 JSON_V1로 Serial 수신기 뼈대 확인
2. 그 다음 v2 바이너리 unpack 추가
3. 같은 로그/렌더 경로에 두 포맷을 선택형으로 연결
4. 실제 센서 도착 후 JSON/BINARY 지연과 누락률 비교
5. 이후 MQTT 같은 무선 경로 실험 시에도 `BINARY_V2` payload 재사용

## 주의

- C 구조체 메모리를 그대로 받는다고 가정하면 안 됩니다.
- 반드시 `shared/protocol/esp32_pi_packet_format.md` 문서 기준으로 unpack 해야 합니다.
- ESP32 기본 포맷이 바뀌면 Pi 쪽 기본 수신 포맷도 같이 맞춰야 합니다.

# Raspberry Pi Mock Test Guide

기존 Raspberry Pi 코드([esp32_serial_receiver.py](/home/lsy/S14P31C203/device/raspberry-pi/esp32_serial_receiver.py), [pi_sensor_bridge.py](/home/lsy/S14P31C203/device/raspberry-pi/pi_sensor_bridge.py))는 건드리지 않고, mock 전용 파일만 추가한 상태입니다.

## 추가된 파일

- `mock_receiver`
- `mock_bridge`
- `mock_esp32_serial_receiver.py`
- `mock_pi_sensor_bridge.py`

## 목적

- 실제 ESP32 없이 Raspberry Pi에서 운동 센서 데이터 흐름 테스트
- 운동 종류별 mock 데이터 생성
- 콘솔 수신 확인
- WebSocket/HUD 브리지 확인

## 가장 간단한 실행

### 1. 콘솔에서 센서값 보기

```bash
cd device/raspberry-pi
./mock_receiver
```

기본값:
- 운동: `pushup`
- 반복: `10`
- 속도: `1.0`
- 강도: `1.0`

### 2. 브리지와 UI까지 같이 보기

```bash
cd device/raspberry-pi
./mock_bridge
```

기본값:
- 운동: `pushup`
- 무한 반복
- 속도: `1.0`
- 강도: `1.0`
- WebSocket: `0.0.0.0:8765`
- UI: `0.0.0.0:8080`

## 운동별 실행 예시

### 이두컬 10회

```bash
cd device/raspberry-pi
./mock_receiver curl
```

### 스쿼트 12회

```bash
cd device/raspberry-pi
./mock_receiver squat 12
```

### 레터럴 레이즈 8회, 속도 1.2, 강도 1.3

```bash
cd device/raspberry-pi
./mock_receiver raise 8 1.2 1.3
```

### 브리지에서 이두컬 무한 반복

```bash
cd device/raspberry-pi
./mock_bridge curl
```

### 브리지에서 스쿼트, 속도 1.2, 강도 1.4

```bash
cd device/raspberry-pi
./mock_bridge squat 1.2 1.4
```

## 인자 설명

### `mock_receiver`

```bash
./mock_receiver [exercise] [reps] [speed] [intensity]
```

- `exercise`: `pushup | curl | squat | raise`
- `reps`: 반복 횟수
- `speed`: 속도 배수, 기본 `1.0`
- `intensity`: 강도 배수, 기본 `1.0`

### `mock_bridge`

```bash
./mock_bridge [exercise] [speed] [intensity] [ws_host] [ws_port] [ui_host] [ui_port]
```

- `exercise`: `pushup | curl | squat | raise`
- `speed`: 속도 배수, 기본 `1.0`
- `intensity`: 강도 배수, 기본 `1.0`
- `ws_host/ws_port`: WebSocket 바인드 주소
- `ui_host/ui_port`: HUD UI 바인드 주소

## 브리지 접속 주소

`./mock_bridge` 실행 후:

```text
WebSocket: ws://<raspberry-pi-ip>:8765
UI:        http://<raspberry-pi-ip>:8080
```

## 내부 동작 구조

```text
run_mock_workout_stream.sh
-> mock BINARY_V2 프레임 생성
-> mock_esp32_serial_receiver.py 또는 mock_pi_sensor_bridge.py 로 stdin 전달
-> Raspberry Pi 콘솔/브리지/UI 테스트
```

## 주의

- mock 데이터는 실측 로그가 아니라 synthetic 운동 패턴입니다.
- UI, 브리지, 상태 전이 테스트에는 적합합니다.
- 실제 threshold 튜닝이나 사용자별 캘리브레이션 검증에는 적합하지 않습니다.

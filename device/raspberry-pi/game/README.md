# IMU Game

라즈베리파이에서 ESP32 IMU 입력을 이용해 테스트할 수 있는 간단한 게임 폴더입니다.

## 현재 포함된 게임

- `index.html`
  - `Lateral Raise Dodger`
  - `IMU1` / `IMU2`를 좌우 팔 입력으로 사용
  - `IMU3`를 몸통 반동 감지용으로 사용

## 게임 규칙

- 왼팔을 빠르게 들어 올리면 플레이어가 왼쪽 레인으로 이동
- 오른팔을 빠르게 들어 올리면 플레이어가 오른쪽 레인으로 이동
- 몸통 흔들림이 크면 `BODY SWAY` 경고와 함께 페널티가 쌓임
- 장애물을 피할수록 점수가 오름

## 실행 방법

### 1. 브리지 먼저 실행

```bash
cd device/raspberry-pi
python3 pi_sensor_bridge.py \
  --serial-port /dev/ttyUSB0 \
  --ws-host 0.0.0.0 \
  --ws-port 8765 \
  --ui-host 0.0.0.0 \
  --ui-port 8080
```

### 2. 게임 페이지 열기

가장 간단한 방법:

```bash
cd device/raspberry-pi/game
python3 -m http.server 8090
```

그 다음 브라우저에서:

```text
http://<raspberry-pi-ip>:8090
```

## 입력 매핑

- `IMU1`: 왼팔
- `IMU2`: 오른팔
- `IMU3`: 몸통

현재 1차 프로토타입이라 절대 각도보다 `gyro` 기반의 빠른 움직임을 먼저 사용합니다.
실제 센서 부착 후에는 운동별 캘리브레이션 데이터를 이용해 threshold를 조정하면 됩니다.

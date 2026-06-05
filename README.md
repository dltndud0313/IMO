# IMO

> Inside Muscle Out - EMG/IMU 기반 운동 자세 분석 서비스

잘못된 운동 자세와 보상 동작은 운동 효율 저하와 부상 위험으로 이어질 수 있습니다.
IMO는 EMG와 IMU 데이터를 활용하여 운동 수행 상태를 분석하고 사용자에게 실시간 피드백을 제공하기 위해 개발한 서비스입니다.

제가 담당한 영역은 device/esp32의 ESP32-S3 센서 수집 펌웨어입니다.

## 담당 파트

제가 주로 담당한 영역은 `device/esp32`의 **ESP32-S3 센서 수집 펌웨어**입니다.

| 담당 영역 | 구현 내용 |
| --- | --- |
| EMG 센서 수집 | 4채널 ADC 입력을 20ms 주기로 수집 |
| IMU 센서 수집 | MPU-6050 3개를 I2C로 읽고 accel/gyro 데이터 처리 |
| EMG 신호 안정화 | baseline 보정, noise floor 제거, RMS/envelope, smoothing 처리 |
| IMU 신호 안정화 | gyro bias 보정, deadzone, EMA smoothing, motion score 계산 |
| 패킷 프로토콜 | Raspberry Pi로 보낼 `BINARY_V2` 64 bytes 고정 프레임 설계/구현 |
| Serial 전송 | USB Serial 기반 실시간 센서 프레임 송신 |
| 하드웨어 분리 대응 | IMU1/2와 IMU3를 서로 다른 I2C bus로 분리 |
| 테스트/디버깅 | 하드웨어 없이 확인 가능한 host test와 decoder script 구성 |

## ESP32 펌웨어 개요

ESP32-S3는 운동 중 착용 센서에서 들어오는 EMG 4채널과 IMU 3개의 데이터를 50Hz로 수집합니다.  
단순 raw 값을 그대로 보내지 않고, ESP32에서 1차 안정화 처리를 수행한 뒤 Raspberry Pi가 읽기 쉬운 고정 길이 바이너리 패킷으로 전송합니다.

```text
EMG 4ch + MPU-6050 x3
  v
ESP32-S3 firmware
  |  - ADC / I2C sensor read
  |  - EMG baseline/noise/RMS/smoothing
  |  - IMU bias/deadzone/EMA
  |  - BINARY_V2 packet encoding
  v
USB Serial
  v
Raspberry Pi
  v
App / Backend / Smart Glass
```

## ESP32 데이터 처리 흐름

```text
every 20ms:
  1. EMG 4채널 ADC raw 값 수집
  2. MPU-6050 3개 accel/gyro 값 수집
  3. EMG baseline 대비 변화량 계산
  4. noise floor 제거 및 RMS/envelope 계산
  5. display smoothing, hold/release 적용
  6. IMU gyro bias, deadzone, EMA smoothing 적용
  7. OutputPacket 생성
  8. BINARY_V2 64 bytes frame으로 encode
  9. USB Serial로 Raspberry Pi에 전송
```

## ESP32 패키지 구조

```text
device/esp32/
├─ firmware/
│  ├─ include/
│  │  ├─ config.h              # 샘플링 주기, GPIO, 필터 상수, 패킷 설정
│  │  ├─ emg_filter.h          # EMG smoothing/RMS interface
│  │  ├─ imu_processor.h       # IMU 보정/필터 interface
│  │  ├─ packet.h              # OutputPacket 및 protocol interface
│  │  ├─ runtime_pipeline.h    # 센서 read -> packet 생성 pipeline
│  │  ├─ sensor_analog_emg.h   # 실제 EMG/IMU sensor source
│  │  └─ transport_serial.h    # Serial transport
│  ├─ src/
│  │  ├─ sensor_analog_emg.cpp # EMG ADC + MPU-6050 I2C 수집
│  │  ├─ emg_filter.cpp        # EMG moving average/RMS/smoothing
│  │  ├─ imu_processor.cpp     # IMU bias/deadzone/EMA/motion score
│  │  ├─ runtime_pipeline.cpp  # 20ms runtime pipeline
│  │  ├─ packet.cpp            # BINARY_V2 frame encode/decode
│  │  └─ transport_serial.cpp  # USB Serial 송신
│  ├─ tests/                   # host test
│  └─ main/main.cpp            # firmware entrypoint
└─ scripts/
   ├─ decode_binary_sensor_stream.py
   ├─ run_firmware_host_tests.sh
   └─ run_mock_workout_stream.sh
```

## 핵심 구현 포인트

### 1. EMG 4채널 신호 안정화

EMG는 부착 위치, 피부 접촉, 미세한 움직임에 따라 raw 값이 흔들리기 쉽습니다.  
그래서 ESP32에서 다음 단계를 거쳐 Pi로 전달할 값을 만들었습니다.

```text
ADC raw
  -> rest baseline 보정
  -> noise floor 제거
  -> frame RMS / envelope 계산
  -> moving average / RMS smoothing
  -> display gain / clamp
  -> hold / release smoothing
```

주요 목적:

- 사람마다 다른 기본 전압을 baseline으로 보정
- 휴식 중 미세 노이즈를 0에 가깝게 정리
- 근육 수축 시 UI 게이지가 자연스럽게 상승/하강하도록 smoothing
- 센서 detach 상황은 일반 근육 수축과 구분해 `1.000` 경고값으로 표시

### 2. IMU 3개 동시 수집

MPU-6050 3개를 사용해 운동 중 움직임 정보를 함께 수집합니다.  
IMU1/2는 같은 I2C bus에서 서로 다른 주소(`0x68`, `0x69`)를 사용하고, IMU3는 별도 I2C bus에서 `0x68` 주소를 다시 사용하도록 분리했습니다.

| IMU | I2C port | SDA | SCL | Address |
| --- | --- | --- | --- | --- |
| IMU1 | 0 | GPIO8 | GPIO9 | `0x68` |
| IMU2 | 0 | GPIO8 | GPIO9 | `0x69` |
| IMU3 | 1 | GPIO10 | GPIO11 | `0x68` |

처리 단계:

- `WHO_AM_I` 확인으로 실제 센서 응답 검증
- sleep 해제 후 accel/gyro raw register read
- 초기 gyro bias 보정
- deadzone으로 정지 상태의 작은 떨림 제거
- EMA smoothing으로 움직임 값 안정화
- motion detection flag 생성

### 3. JSON에서 BINARY_V2 고정 프레임으로 전환

초기에는 JSON 기반 전송을 고려했지만, 20ms 주기에서는 Serial 전송 시간이 부담이 될 수 있었습니다.  
현재는 `BINARY_V2` 64 bytes 고정 프레임으로 전송해 Raspberry Pi 수신기가 일정한 단위로 빠르게 decode할 수 있게 했습니다.

| 항목 | 값 |
| --- | --- |
| 전송 매체 | USB Serial |
| Baudrate | `115200` |
| 샘플링 주기 | `20ms` |
| 전송 주기 | `50Hz` |
| 패킷 포맷 | `BINARY_V2` |
| 프레임 크기 | `64 bytes` |
| 검증 | CRC16-CCITT-FALSE |

프레임 구성:

```text
Header  6 bytes  magic/version/type/payload_len
Payload 56 bytes seq/timestamp/emg/imu/state/flags/rep_index
Tail    2 bytes  crc16
```

### 4. ESP32와 Raspberry Pi 역할 분리

ESP32는 실시간성이 중요한 센서 수집과 1차 안정화만 담당합니다.  
운동 세션 저장, 반복 횟수 판단, 자세 분석, 앱/스마트글래스 연동은 Raspberry Pi와 상위 시스템에서 처리하도록 역할을 분리했습니다.

| 장치 | 역할 |
| --- | --- |
| ESP32-S3 | 센서 raw 수집, EMG/IMU 1차 보정, 바이너리 패킷 송신 |
| Raspberry Pi | 패킷 수신, 운동 분석, 세션 로그 저장, 앱/글래스 연동 |
| Flutter App | 운동 계획, 실시간 피드백, 운동 결과 조회 |
| Backend | 사용자/세션/통계 데이터 관리 |

## 기술 스택

### Device / ESP32

| 기술 | 사용 목적 |
| --- | --- |
| ESP32-S3 | 센서 수집 MCU |
| ESP-IDF | 펌웨어 빌드 및 플래시 |
| C++ | 센서 처리 및 packet pipeline 구현 |
| ADC | EMG 4채널 입력 |
| I2C | MPU-6050 3개 연결 |
| USB Serial | Raspberry Pi로 실시간 데이터 전송 |
| CRC16 | 바이너리 프레임 무결성 검증 |

### 전체 시스템

| 영역 | 기술 |
| --- | --- |
| App | Flutter, Dio, Provider, GoRouter, WebSocket |
| Backend | FastAPI, PostgreSQL, Alembic |
| Edge | Raspberry Pi, WebSocket server |
| Device | ESP32-S3, ESP-IDF |
| Protocol | ESP32-Pi `BINARY_V2`, Pi-App WebSocket JSON |

## 실행 방법

### ESP32 firmware build

```bash
cd device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
```

### Flash

```bash
idf.py -p /dev/ttyUSB0 -b 115200 flash
```

### Serial stream 확인

```bash
./stream
```

또는 decoder script로 `BINARY_V2` 프레임을 확인합니다.

```bash
python3 device/esp32/scripts/decode_binary_sensor_stream.py --port /dev/ttyUSB0
```

### Host test

하드웨어 없이 핵심 로직을 확인할 수 있도록 host test script를 제공합니다.

```bash
./device/esp32/scripts/run_firmware_host_tests.sh
```

## 주요 설정값

`device/esp32/firmware/include/config.h` 기준:

| 설정 | 값 |
| --- | --- |
| `kDefaultPacketFormat` | `BINARY_V2` |
| `kSampleIntervalMs` | `20` |
| `kSerialBaudRate` | `115200` |
| `kAnalogEmgAdcGpios` | `{4, 5, 6, 7}` |
| `kAnalogEmgSamplesPerFrame` | `10` |
| `kEmgMovingAverageWindow` | `16` |
| `kEmgRmsWindow` | `16` |
| `kEmgDisplayGain` | `20.00` |
| `kEmgDisplaySignalMax` | `0.900` |
| `kEmgDisplayMax` | `1.000` |
| `kImuGyroBiasCalibrationSamples` | `100` |
| `kImuGyroDeadzoneDps` | `0.80` |
| `kImuAccelDeadzoneG` | `0.015` |
| `kMotionDetectionThreshold` | `1.50` |

## 프로젝트 구조

```text
S14P31C203/
├─ app/                # Flutter mobile app
├─ backend/            # FastAPI backend server
├─ device/
│  ├─ esp32/           # ESP32-S3 sensor firmware
│  └─ raspberry-pi/    # Raspberry Pi edge logic
├─ docs/               # 설계/측정/프로토콜 문서
├─ shared/
│  └─ protocol/        # ESP32-Pi packet format
└─ tools/              # 개발 보조 도구
```

## 포트폴리오 관점의 성과

- EMG 4채널과 IMU 3개를 50Hz로 수집하는 ESP32-S3 펌웨어 구조 구현
- 센서 raw 값을 그대로 전달하지 않고, baseline/noise/RMS/smoothing을 거친 안정적인 운동 보조용 신호로 가공
- Serial 통신 부담을 줄이기 위해 JSON 대신 64 bytes 고정 길이 바이너리 패킷으로 전환
- IMU 주소 충돌 가능성을 줄이기 위해 I2C bus 구성을 분리하고 센서 응답 검증 흐름을 구성
- 하드웨어 bring-up 과정에서 디버깅 가능한 decoder, mock stream, host test 흐름을 함께 준비

## 참고 문서

- `device/esp32/README.md`
- `device/esp32/firmware/README.md`
- `shared/protocol/esp32_pi_packet_format.md`
- `docs/esp32_packet_protocol_migration.md`
- `docs/esp32_sensor_measurement_guide.md`
- `docs/esp32_emg_sensor_bringup.md`

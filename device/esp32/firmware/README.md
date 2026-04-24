# firmware/

ESP32-S3(ESP-IDF)용 펌웨어 뼈대입니다.  
핵심 목적은 하드웨어가 없어도 `가짜 센서 -> 처리 -> 패킷` 흐름을 먼저 검증하는 것입니다.

현재는 mock 파이프라인을 보존하면서, `SZH-GJD001` 계열 단일 아날로그 EMG 센서와
`MPU-6050` 계열 IMU를 함께 다루는 실센서 어댑터(`src/sensor_analog_emg.cpp`)도 포함되어 있습니다.

패킷 계층은 초기 v1 JSONL 시도안을 보존하면서, 실시간 경로 최종안은 v2 바이너리 프로토콜로 전환하는 방향으로 정리합니다.

## 하위 폴더

- `include/`: 공용 타입, 인터페이스, 설정값
- `src/`: 실제 로직 구현
- `main/`: ESP-IDF 진입점(`app_main`)
- `tests/`: Ubuntu 호스트 기반 C++ 테스트
- `tools/`: 가짜 패킷 발생기 같은 보조 실행 파일

### `include/`

- 헤더 파일 모음입니다.
- 데이터 구조: `types.h`
- 설정 상수: `config.h`
- 모듈 경계: `packet.h`, `emg_filter.h`, `imu_processor.h`, `calibration.h`, `state_machine.h`
- 확장 포인트: `sensor_source.h`, `transport_serial.h`
- 처음 볼 때는 `types.h -> sensor_source.h -> config.h` 순서가 가장 좋습니다.

### `src/`

- `include/`에서 선언한 기능의 실제 구현이 들어 있습니다.
- `runtime_pipeline.cpp`: 센서 입력부터 패킷 송출까지 한 주기 전체 흐름
- `packet.cpp`: `JSON_V1`, `BINARY_V2` 직렬화/역직렬화
- `emg_filter.cpp`, `imu_processor.cpp`: 경량 전처리
- `calibration.cpp`, `state_machine.cpp`: 캘리브레이션/상태 제어

### `main/`

- ESP-IDF 진입점 폴더입니다.
- `main.cpp`의 `app_main()`이 실제 디바이스 실행 시작점입니다.
- 현재는 `AnalogEmgSensorSource`를 기본으로 연결해, IMU는 실제 I2C 값을 읽고 EMG는 ADC 미연동 시 `0`으로 유지하게 구성되어 있습니다.

### `tests/`

- Ubuntu 22.04에서 펌웨어 핵심 로직을 검증하는 호스트 기반 테스트입니다.
- 테스트 항목:
  - 패킷 인코딩/디코딩
  - EMG 계산(RMS/이동평균/정규화)
  - 캘리브레이션 누적
  - 상태머신 전이
  - 가짜 센서 신호 변화
- 실행:

```bash
./device/esp32/scripts/run_firmware_host_tests.sh
```

### `tools/`

- 개발 보조 실행 파일을 둡니다.
- `mock_stream_main.cpp`: ESP32 없이 패킷을 생성하는 호스트용 발생기
- 주요 사용처:
  - Pi receiver와 end-to-end 파이프라인 연결 검증
  - 하드웨어 도착 전 통신/파싱/로그 경로 확인
  - JSON/BINARY 포맷 비교 테스트

## 빠른 검증

```bash
./device/esp32/scripts/run_firmware_host_tests.sh
```

## 실제 IMU 빠른 확인

- 현재 기본 전제 IMU는 `MPU-6050` 입니다.
- 기본 I2C 핀은 `device/esp32/firmware/include/config.h` 기준으로 `SDA=GPIO8`, `SCL=GPIO9` 입니다.
- 보드 배선이 다르면 아래 값을 먼저 바꿔야 합니다.
  - `kImuI2cSdaGpio`
  - `kImuI2cSclGpio`
  - `kMpu6050Address`

JSON으로 실제 IMU 값을 보려면:

```bash
cd ./device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyUSB0 -b 115200 flash monitor
```

- `JSON_V1`일 때는 `acc_x`, `acc_y`, `acc_z`, `gyro_x`, `gyro_y`, `gyro_z`가 사람이 읽는 값으로 출력됩니다.
- 현재 구현 기준으로는 IMU는 실센서 값, EMG는 ADC 미연동이면 `0`에 가깝게 나옵니다.
- 현재 기본 EMG 입력은 `GPIO4` 아날로그 핀입니다. EMG 모듈 출력이 이 핀에 연결되면 `emg_ch1`로 반영됩니다.
- `emg_ch1`가 계속 `0`이면 `kEnableEmgRawSerialPlotterMode = true`로 바꿔 raw ADC 값부터 확인하는 것이 좋습니다.
- 현재 기본 설정에서는 `kEnableEmgBringupPacketMode = false`라서 `emg_ch1`에 normalized 값이 실립니다.
- 실센서 입력 확인이 필요할 때만 `kEnableEmgBringupPacketMode = true`로 바꿔 EMG RMS/envelope를 직접 확인합니다.
- 부팅 직후 약 `2초` 동안은 자이로 bias 보정을 위해 보드를 가만히 두는 것이 좋습니다.
- 현재 기본 IMU 보정값:
  - `kImuGyroBiasCalibrationSamples = 100`
  - `kImuSmoothingAlpha = 0.20`
  - `kMotionDetectionThreshold = 0.50`

## 빠르게 봐야 할 문서 기준

- 패킷 필드 이름과 예시값
  - `../README.md`
- `state` 값 의미
  - `../README.md`
- ESP32-Pi 공통 패킷 포맷(v2 binary)
  - `../../shared/protocol/esp32_pi_packet_format.md`
- ESP32-Pi 공통 패킷 포맷(v1 JSONL archive)
  - `../../shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`
- 패킷 전환 배경/영향 범위
  - `../../docs/esp32_packet_protocol_migration.md`

## 패킷 전환 메모

- 현재 코드에서 바로 확인되는 출력은 v1 JSONL입니다.
- 하지만 실시간 경로 기준 권장안은 v2 바이너리입니다.
- 현재 구현은 `JSON_V1`, `BINARY_V2` 를 모두 유지하고 `config.h`에서 기본 포맷을 선택할 수 있습니다.
- 전환 이유:
  - 문자열 생성/파싱 비용 제거
  - Serial 대역폭 사용량 감소
  - `115200 baud` 기준 전송 시간 단축
- 추정 비교:
  - v1 JSON 예시: 약 `228 bytes`
  - v2 Binary 프레임: 약 `38 bytes`
  - 전송 바이트 수: 약 `83%` 감소

즉, 센서 처리 로직은 유지하고 `packet.cpp`, `transport_serial.cpp` 중심으로 전송 계층을 바꾸는 것이 핵심입니다.

나중에 MQTT 같은 무선 경로를 붙일 때도 `PacketBuffer`를 그대로 publish payload로 재사용하는 구조를 우선합니다.

## 하드웨어 도착 후 교체

- `src/sensor_mock.cpp` `(실제 장착 후 변경 필요)`
  - mock 입력을 실제 센서 입력 코드로 교체
- `src/sensor_analog_emg.cpp` `(실제 장착 후 우선 검토 대상)`
  - SZH-GJD001 계열 단일 아날로그 EMG 센서와 `MPU-6050` IMU를 함께 읽는 어댑터
  - 센서 예제의 500Hz band-pass 필터 아이디어를 EMG 경로에 적용했고, IMU는 I2C로 실제 값을 읽습니다
  - 현재 EMG ADC 기본 입력은 `GPIO4` 입니다
- `include/config.h` `(실제 장착 후 설정값 조정 필요)`
  - threshold, 샘플링 주기, smoothing 계수 튜닝
- `src/emg_filter.cpp`, `src/calibration.cpp` `(실제 장착 후 튜닝 가능성 높음)`
  - 실측 데이터 기준으로 EMG 처리 파라미터 조정
- 패킷 스키마(`emg-glass.v1`)는 Pi와의 호환을 위해 유지 권장
- v1 JSONL 필드 이름(`schema`, `emg_ch1`, `state` 등)은 archive 기준으로 유지
- v2 binary는 상태 코드와 고정 순서 payload를 사용

## SZH-GJD001 센서 기준 수정 순서

1. `src/sensor_analog_emg.cpp`
   - `read_raw_sample()`에 ESP-IDF ADC 읽기 코드를 연결
   - `read_imu_sample()`의 I2C 핀과 주소가 실제 배선과 맞는지 확인
2. `main/main.cpp`
   - `MockSensorSource` 대신 실제 센서 어댑터를 연결
3. `include/config.h`
   - 샘플 수, ADC full scale, threshold 조정
4. `src/emg_filter.cpp`
   - 실제 센서 노이즈에 맞춰 RMS / 이동평균 / threshold 튜닝
5. `src/calibration.cpp`
   - rest / MVC 기준이 실제 사용자 데이터에 맞는지 확인

값이 안 잡히면 가장 먼저 `src/sensor_analog_emg.cpp`와 ADC 핀 설정부터 확인하는 것이 좋습니다.

## 문서 정리 메모

- 폴더별 짧은 README는 중복을 줄이기 위해 이 문서로 통합했습니다.
- 기존 하위 README 원본은 `docs/archive/firmware_readmes/` 아래에 보관합니다.

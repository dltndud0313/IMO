# ESP32 Firmware (ESP-IDF)

현재 펌웨어는 **저지연 데이터 수집 장치** 역할에 집중합니다.

- ESP32 내부 캘리브레이션 없음
- 전원 인가 후 즉시 `STREAMING`
- EMG 4채널 + IMU 3개 수집
- 기본 전송: `BINARY_V2` 64바이트 고정 프레임

## 실행

```bash
cd ./device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyUSB0 -b 115200 flash monitor
```

## 호스트 테스트

```bash
./device/esp32/scripts/run_firmware_host_tests.sh
```

## 현재 설정 핵심값

`include/config.h` 기준:

- `kDefaultPacketFormat = BINARY_V2`
- `kSampleIntervalMs = 20` (50Hz)
- `kAnalogEmgAdcGpios = {4,5,6,7}`
- `kMpu6050Addresses = {0x68,0x69,0x6A}`
- `kImuI2cSdaGpio = 8`, `kImuI2cSclGpio = 9`
- `kImuGyroBiasCalibrationSamples = 100`
- `kImuGyroDeadzoneDps = 0.80`
- `kImuAccelDeadzoneG = 0.015`
- `kMotionDetectionThreshold = 1.50`

## EMG 최종 동작 목표

현재 EMG는 운동보조용 게이지처럼 보이는 것을 목표로 튜닝했다.

- 부착 직후 휴식 상태는 `0.000`
- 힘을 주면 힘 크기에 따라 값이 상승
- 힘을 유지하면 값이 급락하지 않도록 표시값을 smoothing
- 힘을 빼면 자연스럽게 감소
- 센서 탈착 시에는 경고값 `1.000`
- 일반 근육 수축 게이지 상한은 `0.900`

## EMG 튜닝 메모

`include/config.h` 기준 현재 EMG 관련 핵심값:

- `kSampleIntervalMs = 20`
- `kEmgMovingAverageWindow = 16`
- `kEmgRmsWindow = 16`
- `kEmgHistoryWindow = 40`
- `kEmgDisplayAttackAlpha = 0.12`
- `kEmgDisplayReleaseAlpha = 0.99`
- `kEmgDisplayZeroReleaseAlpha = 0.040`
- `kEmgDisplayHoldFrames = 18`
- `kEmgRestDisplayThreshold = 0.010`
- `kActivationThresholdOn = 0.011`
- `kEmgDisplayGain = 20.00`
- `kEmgDisplaySignalMax = 0.900`
- `kEmgDisplayMax = 1.000`
- `kAnalogEmgRestBaselineSamples = 100`
- `kAnalogEmgFrameNoiseFloor = 0.001`
- `kAnalogEmgDetachedMagnitudeThreshold = 0.42`
- `kAnalogEmgReattachMagnitudeThreshold = 0.08`
- `kAnalogEmgReattachConsecutiveFrames = 5`

## 구현 변경 요약

초기 구현 대비 현재 변경점:

- ESP32 내부 캘리브레이션 상태 제거
- 전원 인가 후 즉시 `STREAMING`
- EMG 4채널/IMU 3개 구조로 통일
- 현재 실사용 채널은 `GPIO4` 1채널, 나머지 EMG 채널은 비활성화
- IMU는 `0x68`, `0x69` 2개 활성, `0x6A` 슬롯은 예비
- EMG는 raw ADC 기준선 대비 변화량을 envelope로 사용
- 일반 근육 신호와 탈착 경고 상한을 분리
- `./stream` 래퍼로 실시간 수신 명령 단축

## 빠른 비교 포인트

포트폴리오/보고서에 바로 옮길 때 강조할 수 있는 비교 항목:

- 상태머신:
  - 초기: ESP32 내부 캘리브레이션 단계 존재
  - 현재: 캘리브레이션 제거, 즉시 스트리밍
- 패킷:
  - 초기: 가변/텍스트 중심 실험 단계
  - 현재: `BINARY_V2` 64바이트 고정
- EMG 처리:
  - 초기: band-pass/정규화 실험
  - 현재: baseline 대비 envelope + 표시용 smoothing
- EMG 표시:
  - 초기: 최대 `1.000` 단일 상한
  - 현재: 근육 수축 상한 `0.900`, 탈착 경고 `1.000`
- 실행 편의:
  - 초기: 긴 Python 디코더 명령 직접 입력
  - 현재: `./stream`

## Troubleshooting

실제 bring-up 중 자주 나온 문제와 대응:

| 증상 | 원인 추정 | 대응 |
| --- | --- | --- |
| IMU2가 계속 `0,0,0` 으로 보임 | I2C 주소 probe는 되었지만 `WHO_AM_I` 검증/채널 준비 상태가 불완전했음 | I2C scan, `WHO_AM_I`, sample read를 분리 확인하고 `0x68/0x69` 두 채널만 활성화 |
| 디코더 로그가 움직일 때만 보이거나 중간에 끊김 | 텍스트 로그가 바이너리 프레임을 깨뜨리거나 포트 점유 충돌 | `BINARY_V2` 수신 중 텍스트 init 로그 비활성화, monitor와 decoder 동시 사용 금지 |
| EMG가 탈착 후 다시 붙여도 이상한 기준값에서 시작 | 이전 baseline이 재부착 후에도 영향 | 탈착/재부착 로직과 baseline reset을 여러 방식으로 실험했고, 최종값은 안정 위주로 정리 |
| 힘 유지 중 EMG 값이 급락 | raw EMG의 순간적인 dip가 표시값에 바로 반영 | moving average, RMS, hold frame, release alpha를 조정해 게이지 성격으로 완화 |
| 손으로 눌러야 EMG가 잘 잡힘 | 전극 접촉 저항이 높거나 부착 위치가 불안정 | 코드 튜닝보다 전극 위치/접촉 안정화가 우선, baseline은 힘을 뺀 상태에서 시작 |
| `idf.py`가 안 잡힘 | ESP-IDF 환경 미로딩 | `source ~/esp/esp-idf/export.sh` 후 실행 |

실시간 디버깅 체크 순서:

1. `source ~/esp/esp-idf/export.sh`
2. `idf.py build flash`
3. `./stream`
4. IMU는 주소 인식/자세 반응부터 확인
5. EMG는 부착 직후 휴식 `0.000`, 수축 상승, 탈착 `1.000` 순으로 확인

## 모듈 역할

- `src/sensor_analog_emg.cpp`
  - EMG 4채널 ADC + MPU-6050 3개 I2C 수집
- `src/emg_filter.cpp`
  - 채널별 RMS + 표시용 smoothing + hysteresis active
- `src/imu_processor.cpp`
  - gyro bias + deadzone + EMA + motion delta
- `src/runtime_pipeline.cpp`
  - 센서 프레임 처리 후 패킷 생성/송신
- `src/packet.cpp`
  - JSON/BINARY 인코딩/디코딩

## Pi 연동

64바이트 프레임 디코드:

```bash
python3 ./device/esp32/scripts/decode_binary_sensor_stream.py --port /dev/ttyUSB0
```

프로토콜 상세:

- `shared/protocol/esp32_pi_packet_format.md`

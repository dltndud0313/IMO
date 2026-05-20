# ESP32 센서 수집 펌웨어 최종 정리

이 파일이 **ESP32 작업 내용을 대표하는 README**입니다.

PPT/포트폴리오에 ESP32 파트를 정리할 때는 이 문서를 먼저 보면 됩니다.  
세부 측정 절차나 긴 트러블슈팅은 `docs/` 문서를 참고용으로 분리했습니다.

## 한 줄 요약

ESP32-S3에서 EMG 4채널과 MPU-6050 IMU 3개를 50Hz로 수집하고, USB Serial `BINARY_V2` 64바이트 고정 프레임으로 Raspberry Pi에 전달하는 저지연 센서 수집 펌웨어입니다.

## 현재 구현 상태

- ESP32 내부 운동 판정용 캘리브레이션 상태 제거
- 센서 안정화용 baseline/noise 보정은 ESP32에서 수행
- 전원 인가 후 즉시 `STREAMING`
- EMG 4채널 ADC 입력 처리
- IMU 3개 I2C 입력 처리
- EMG 표시값 smoothing, hold, release 튜닝
- 센서 탈착 경고값 분리
- USB Serial 바이너리 프레임 송신
- Raspberry Pi 디코더/로그 저장 경로와 연동 가능
- 하드웨어 없이 확인 가능한 host test 유지

## 센서 구성

| 구분 | 현재 설정 |
| --- | --- |
| EMG | 4채널 ADC |
| EMG GPIO | `GPIO4/5/6/7` |
| IMU | MPU-6050 3개 |
| IMU1 | `I2C port=0`, `SDA=GPIO8`, `SCL=GPIO9`, `address=0x68` |
| IMU2 | `I2C port=0`, `SDA=GPIO8`, `SCL=GPIO9`, `address=0x69` |
| IMU3 | `I2C port=1`, `SDA=GPIO10`, `SCL=GPIO11`, `address=0x68` |
| 송신 주기 | `20ms`, 약 `50Hz` |
| 기본 전송 | USB Serial |
| 기본 패킷 | `BINARY_V2`, 64바이트 고정 프레임 |

## 실행 방법

ESP-IDF 환경을 로드한 뒤 빌드합니다.

```bash
cd ./device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
```

ESP32에 업로드합니다.

```bash
idf.py -p /dev/ttyUSB0 -b 115200 flash
```

실시간 센서값을 확인합니다.

```bash
./stream
```

포트가 다르면 먼저 확인합니다.

```bash
ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

## 코드 흐름

현재 펌웨어의 핵심 흐름은 아래와 같습니다.

```text
sensor_analog_emg.cpp
  -> EMG ADC 4채널 raw 입력, baseline 대비 envelope 생성

imu_processor.cpp
  -> MPU-6050 3개 accel/gyro 입력, bias/deadzone 처리

emg_filter.cpp
  -> EMG moving average, RMS, display smoothing, hold/release 처리

runtime_pipeline.cpp
  -> 센서 읽기, 처리 결과 취합, OutputPacket 생성

packet.cpp
  -> OutputPacket을 BINARY_V2 64바이트 wire frame으로 변환

transport_serial.cpp
  -> USB Serial 송신
```

## 전체 동작을 쉽게 풀어쓴 설명

ESP32는 운동을 최종 판단하는 장치가 아니라, **센서값을 빠르게 읽고 보기 좋은 형태로 1차 정리해서 Pi로 보내는 장치**입니다.

전체 흐름은 아래처럼 생각하면 됩니다.

```text
1. EMG/IMU 센서에서 raw 값 읽기
2. 너무 튀는 값, 기준선 차이, 작은 노이즈를 ESP32에서 1차 정리
3. 화면/게이지에 쓰기 좋은 값으로 부드럽게 만들기
4. 64바이트 바이너리 패킷으로 압축
5. USB Serial로 Raspberry Pi에 전송
6. Pi에서 로그 저장, 운동 횟수/자세 판단, UI 표시 처리
```

중요한 구분:

- ESP32에서 제거한 것: 사용자별 운동 판정 캘리브레이션, MVC 같은 무거운 상태 절차
- ESP32에 남긴 것: 센서가 안정적으로 보이기 위한 baseline, noise floor, smoothing, hold/release

즉, “캘리브레이션을 완전히 안 한다”가 아니라 **운동 판단용 캘리브레이션은 Pi로 넘기고, 센서 신호 안정화용 보정은 ESP32에서 가볍게 한다**가 정확한 표현입니다.

## EMG 값이 만들어지는 과정

EMG는 건식 전극과 피부 접촉 상태 때문에 raw 값이 많이 흔들립니다. 그래서 ESP32에서 한 번에 바로 보내지 않고, 아래 단계를 거칩니다.

| 단계 | 위치 | 하는 일 | 이유 |
| --- | --- | --- | --- |
| 1. ADC raw 읽기 | `sensor_analog_emg.cpp` | `GPIO4/5/6/7`에서 EMG 4채널 ADC 값을 읽음 | 실제 센서 전압을 숫자로 변환 |
| 2. 시작 baseline 수집 | `sensor_analog_emg.cpp` | 부팅 직후 힘을 뺀 상태의 평균 raw 값을 채널별 기준선으로 저장 | 사람마다/전극마다 기본 전압이 달라서 기준선이 필요 |
| 3. baseline 대비 변화량 계산 | `sensor_analog_emg.cpp` | 현재 raw와 baseline의 차이를 구함 | 절대 raw 값이 아니라 “휴식 대비 얼마나 변했는지”를 보기 위해 |
| 4. noise floor 제거 | `sensor_analog_emg.cpp` | 휴식 중 흔들림보다 작은 변화는 0으로 처리 | 가만히 있어도 생기는 미세 노이즈 제거 |
| 5. frame RMS 계산 | `sensor_analog_emg.cpp` | 20ms 프레임 안의 여러 샘플을 RMS로 묶음 | 순간 튐 하나보다 프레임 전체의 신호 세기를 보기 위해 |
| 6. 이동평균/RMS 재계산 | `emg_filter.cpp` | 최근 값들을 다시 평균/RMS 처리 | 게이지가 너무 덜컥거리거나 순간적으로 꺼지는 것 완화 |
| 7. display gain/clamp | `emg_filter.cpp` | 보기 좋은 범위로 키우고 `0.900` 상한 적용 | UI 게이지에서 값이 너무 작거나 과하게 튀지 않도록 조정 |
| 8. hold/release smoothing | `emg_filter.cpp` | 힘 유지 중 급락 완화, 힘 뺄 때 자연스럽게 감소 | 실제 운동 게이지처럼 보이게 만들기 위해 |
| 9. 탈착 감지 | `sensor_analog_emg.cpp`, `emg_filter.cpp` | 센서가 떨어진 것으로 보이면 `1.000` 경고값 출력 | 일반 힘 신호와 센서 이상을 구분 |

정리하면 EMG는 크게 **baseline 보정 -> noise 제거 -> RMS/envelope -> moving average/RMS -> display smoothing** 순서로 처리됩니다.  
그래서 “필터를 2번 또는 3번 하냐”라고 물으면, 실제로는 목적이 다른 안정화가 여러 단계 들어갑니다.

### EMG 처리에서 각 단계가 필요한 이유

- `baseline`: 센서를 붙인 사람과 위치마다 기본 전압이 다르기 때문에 휴식 기준을 잡습니다.
- `noise floor`: 힘을 안 줘도 ADC와 전극 접촉 때문에 작은 흔들림이 생겨서, 이 구간은 0으로 붙입니다.
- `RMS`: EMG처럼 흔들리는 신호를 평균적인 세기로 바꿉니다.
- `moving average`: 화면에 보이는 값이 너무 빠르게 튀지 않게 합니다.
- `hold`: 힘을 유지하는 중간에 신호가 짧게 꺼져도 게이지가 바로 꺼지지 않게 합니다.
- `release`: 힘을 뺐을 때 값이 너무 오래 남지 않도록 하강 속도를 조정합니다.
- `detach`: 전극이 떨어진 상태를 일반 근육 신호와 구분합니다.

## IMU 값이 만들어지는 과정

IMU는 `MPU-6050` 3개를 읽습니다. IMU 쪽도 raw 값을 그대로 쓰지 않고 안정화 단계를 거칩니다.

| 단계 | 위치 | 하는 일 | 이유 |
| --- | --- | --- | --- |
| 1. I2C 초기화 | `sensor_analog_emg.cpp` | I2C 버스와 MPU-6050 장치를 등록 | 센서와 통신하기 위한 준비 |
| 2. `WHO_AM_I` 확인 | `sensor_analog_emg.cpp` | 실제 MPU 계열 센서가 응답하는지 확인 | 주소만 맞고 실제 읽기가 안 되는 경우 분리 |
| 3. wake 처리 | `sensor_analog_emg.cpp` | MPU-6050 sleep 해제 | 부팅 직후 센서가 잠들어 있는 상태 방지 |
| 4. accel/gyro raw 읽기 | `sensor_analog_emg.cpp` | 가속도/자이로 raw register 읽기 | 실제 움직임 데이터 확보 |
| 5. gyro bias 보정 | `imu_processor.cpp` | 부팅 직후 약 100프레임 평균을 자이로 영점으로 사용 | 정지 상태에서도 자이로가 0이 아닌 문제 보정 |
| 6. deadzone 처리 | `imu_processor.cpp` | 너무 작은 accel/gyro 값은 0으로 처리 | 정지 상태의 미세 떨림 제거 |
| 7. EMA smoothing | `imu_processor.cpp` | 지수이동평균으로 accel/gyro를 부드럽게 처리 | 움직임 값이 너무 튀지 않게 안정화 |
| 8. motion score 계산 | `imu_processor.cpp` | 자이로 절대값 평균으로 움직임 정도 계산 | Pi/UI에서 움직임 여부를 빠르게 참고 |

IMU는 EMG처럼 근육 세기를 계산하지 않습니다. 대신 **자이로 영점 보정, 작은 흔들림 제거, 부드러운 움직임 값 생성**에 집중합니다.

## 부팅 후 실제 실행 순서

ESP32에 전원이 들어오면 아래 순서로 동작합니다.

1. `main.cpp`에서 센서 소스, 파이프라인, Serial transport를 준비합니다.
2. `AnalogEmgSensorSource`가 EMG ADC와 IMU I2C 장치를 사용할 준비를 합니다.
3. IMU는 `WHO_AM_I`를 읽어 실제 센서가 응답하는지 확인하고, sleep 상태를 해제합니다.
4. 펌웨어는 별도 대기 상태 없이 `STREAMING` 상태로 들어갑니다.
5. 매 `20ms`마다 `runtime_pipeline.cpp`의 `tick()`이 한 번 실행됩니다.
6. `tick()` 안에서 EMG 4채널과 IMU 3개의 현재 값을 읽습니다.
7. EMG는 `emg_filter.cpp`를 거쳐 표시용 값으로 바뀝니다.
8. IMU는 `imu_processor.cpp`를 거쳐 bias/deadzone/smoothing이 적용됩니다.
9. 처리 결과를 `OutputPacket` 하나로 묶습니다.
10. `packet.cpp`가 `OutputPacket`을 `BINARY_V2` 64바이트 프레임으로 바꿉니다.
11. `transport_serial.cpp`가 USB Serial로 Pi에 보냅니다.

반복 구조를 코드 기준으로 단순화하면 아래와 같습니다.

```text
while true, every 20ms:
  frame = sensor_source.read_frame(timestamp)
  emg_result = emg_filter.process(frame.emg)
  imu_result[0..2] = imu_processor.process(frame.imu[0..2])
  packet = build_packet(timestamp, emg_result, imu_result)
  serial.send(packet)
```

## Pi로 보내는 패킷에 들어가는 값

ESP32는 raw ADC 값을 그대로 보내지 않습니다. Pi에는 **이미 1차 정리된 값**을 보냅니다.

| 필드 | 내용 |
| --- | --- |
| `seq` | 몇 번째 프레임인지 나타내는 순번 |
| `timestamp_ms` | ESP32 기준 timestamp |
| `emg[0..3]` | EMG 4채널 display 값, 일반 수축은 최대 `0.900`, 탈착은 `1.000` |
| `imu1 accel/gyro` | IMU1의 smoothing된 가속도/자이로 |
| `imu2 accel/gyro` | IMU2의 smoothing된 가속도/자이로 |
| `imu3 accel/gyro` | IMU3의 smoothing된 가속도/자이로 |
| `state` | 현재 상태, 기본은 `STREAMING` |
| `flags` | mock 여부, IMU bias 준비 여부, motion 감지 여부 등 |
| `rep_index` | ESP32에서는 기본 `-1`, 반복 운동 판단은 Pi에서 처리 |

패킷을 바이너리로 보내는 이유:

- JSON은 사람이 읽기 쉽지만 문자열 길이가 길어 Serial 전송 시간이 큽니다.
- `BINARY_V2`는 항상 64바이트라 Pi 수신기가 프레임을 일정하게 읽을 수 있습니다.
- 같은 `115200 baud`에서도 JSON보다 전송 시간이 짧아 20ms 주기에 여유가 생깁니다.

## 정량 비교 포인트

PPT/포트폴리오에 바로 사용할 수 있는 수치입니다.

| 항목 | 현재 값 | 의미 |
| --- | --- | --- |
| 센서 구성 | EMG 4채널 + IMU 3개 | ESP32에서 동시에 수집 |
| 송신 주기 | `20ms` | 약 `50Hz` |
| 패킷 포맷 | `BINARY_V2` | 실시간 USB Serial 경로 |
| 프레임 크기 | `64 bytes` | 고정 길이 프레임 |
| 115200 baud 전송 시간 | 약 `5.56ms/frame` | 64 bytes x 10 bits / 115200 |
| JSON 대비 전송량 | 약 `71.9%` 감소 | 228 bytes 추정 JSON 대비 |

요약 문장:

- 기존 JSON 기반 송신은 20ms 주기에서 전송 시간만 약 19.8ms를 사용했지만, `BINARY_V2`는 약 5.56ms로 줄여 실시간 처리 여유를 확보했습니다.
- ESP32는 센서 수집과 1차 안정화에 집중하고, 세션 저장과 운동 판단은 Raspberry Pi에서 처리하도록 역할을 분리했습니다.

## EMG 튜닝 목표

현재 EMG는 의료용 절대 측정이 아니라 **운동보조용 실시간 게이지**를 목표로 튜닝했습니다.

- 부착 직후 휴식 상태는 `0.000`
- 힘을 주면 값 상승
- 힘 유지 중에는 값이 급락하지 않도록 완화
- 힘을 빼면 자연스럽게 감소
- 일반 근육 수축 상한은 `0.900`
- 센서 탈착 경고는 `1.000`

핵심 튜닝값은 `device/esp32/firmware/include/config.h`에 있습니다.

| 항목 | 값 | 의미 |
| --- | --- | --- |
| `kEmgDisplayAttackAlpha` | `0.12` | 상승 반응 속도 |
| `kEmgDisplayReleaseAlpha` | `0.78` | 하강 반응 속도 |
| `kEmgDisplayZeroReleaseAlpha` | `0.10` | 0 근처 복귀 속도 |
| `kEmgDisplayHoldFrames` | `6` | 유지 중 급락 완화 프레임 |
| `kEmgDisplayHoldRawThreshold` | `0.020` | hold 재충전 raw 기준 |
| `kEmgDisplayHoldDisplayThreshold` | `0.200` | 이전 표시값 유지 최소 기준 |
| `kEmgRestDisplayThreshold` | `0.010` | 휴식으로 보고 0에 붙이는 기준 |
| `kEmgDisplayGain` | `20.00` | 게이지 증폭 계수 |
| `kEmgDisplaySignalMax` | `0.900` | 일반 수축 표시 상한 |
| `kEmgDisplayMax` | `1.000` | 탈착 포함 전체 표시 상한 |

## 주요 개선 내용

- JSON 문자열 송신 중심 구조에서 `BINARY_V2` 고정 프레임으로 전환했습니다.
- ESP32 내부 캘리브레이션 단계를 제거해 부팅 후 바로 스트리밍하도록 단순화했습니다.
- EMG는 baseline 대비 변화량 envelope로 처리하고, 표시 안정화를 위해 moving average/RMS/smoothing을 적용했습니다.
- EMG raw 값에 바로 threshold를 걸지 않고 baseline, noise floor, RMS, display smoothing을 순서대로 적용했습니다.
- 힘 유지 중 값이 순간적으로 꺼지는 문제를 hold 로직으로 완화했습니다.
- 작은 잔류 노이즈가 `0.900` 상한을 계속 유지시키는 문제를 줄이기 위해 hold 재충전 기준을 raw threshold와 display threshold로 분리했습니다.
- IMU3를 별도 I2C 버스로 분리해 주소 충돌과 단일 버스 가정을 줄였습니다.

## ESP32와 Raspberry Pi 역할 분리

실시간 경로에서 ESP32는 가볍게 유지해야 합니다. 그래서 역할을 아래처럼 나눴습니다.

| 장치 | 담당 |
| --- | --- |
| ESP32 | 센서 raw 읽기, baseline/noise 보정, EMG/IMU 1차 안정화, 바이너리 패킷 송신 |
| Raspberry Pi | 패킷 수신, 세션 로그 저장, 운동별 분석, 반복 횟수/자세 판단, UI/글래스 연동 |

이렇게 나눈 이유:

- ESP32에서 무거운 운동 분석까지 하면 20ms 주기를 안정적으로 유지하기 어렵습니다.
- Pi는 로그 저장과 분석을 하기 좋고, 나중에 운동별 로직을 바꾸기도 쉽습니다.
- ESP32-Pi 사이 패킷 포맷만 유지하면 센서 처리와 UI 처리를 독립적으로 수정할 수 있습니다.

## 테스트 방법

하드웨어 없이 펌웨어 핵심 로직을 확인합니다.

```bash
./device/esp32/scripts/run_firmware_host_tests.sh
```

실제 보드에서는 아래 순서로 확인합니다.

1. ESP32 플래시
2. `./stream` 실행
3. EMG 4채널이 이완/수축에 따라 변하는지 확인
4. IMU 3개가 자세 변화에 따라 변하는지 확인
5. Raspberry Pi 저장 스크립트로 세션 로그 저장

## 자주 나온 문제

| 증상 | 원인 | 대응 |
| --- | --- | --- |
| IMU 일부가 `0,0,0`으로 보임 | I2C 주소 probe와 실제 sample read는 별개 | `WHO_AM_I`, wake, sample read를 분리 확인 |
| IMU1/IMU3 값이 만질 때 멈춤 | 배선/접촉/전원/GND 문제 가능성 | 단독 테스트, 공통 GND/VCC 교체, 모듈 교차 테스트 |
| 디코더에 깨진 문자가 보임 | 바이너리 프레임을 텍스트처럼 출력 | `./stream` 또는 Pi binary decoder 사용 |
| EMG가 `0.900`에 오래 붙음 | hold 로직이 작은 잔류값에 계속 갱신 | hold raw/display threshold 분리 |
| EMG가 손으로 눌러야 잘 잡힘 | 전극 접촉 저항/부착 위치 영향 | 부착 위치와 접촉 안정화 후 baseline 시작 |

## 관련 문서

상세 내용이 필요할 때만 아래 문서를 봅니다.

- `firmware/README.md`
  - ESP-IDF 실행 방법, 핵심 설정값, 코드 구조, 튜닝값
- `../../docs/esp32_sensor_measurement_guide.md`
  - 측정 절차, 포트폴리오 문장, 긴 트러블슈팅
- `../../shared/protocol/esp32_pi_packet_format.md`
  - ESP32-Pi 공통 바이너리 패킷 포맷
- `../../docs/esp32_packet_protocol_migration.md`
  - JSON에서 `BINARY_V2`로 바꾼 이유와 정량 비교
- `../../docs/esp32_emg_sensor_bringup.md`
  - EMG/IMU 실제 배선 후 값이 안 잡힐 때 확인 순서

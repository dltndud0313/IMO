# device/esp32

ESP32-S3 기반 센서 송신 코드를 관리하는 폴더입니다.

현재 들어 있는 코드는 **실제 EMG 센서와 IMU가 아직 도착하기 전**, 전체 데이터 흐름을 먼저 검증하기 위해 작성한 **mock 기반 사전 구현 코드**입니다.

즉, 지금 목표는 아래 흐름을 하드웨어 없이 먼저 고정하는 것입니다.

- 가짜 센서 입력 생성
- EMG 처리
- 캘리브레이션
- 상태머신 전이
- JSONL 패킷 생성
- USB Serial 송신 준비

## 구성

- `firmware/`
  - ESP-IDF 프로젝트 루트입니다.
  - mock 센서 입력, EMG 처리, 캘리브레이션, 상태머신, JSONL 패킷 생성, Serial 송신 코드가 들어 있습니다.
- `scripts/`
  - Ubuntu 22.04에서 하드웨어 없이 핵심 로직을 검증하는 보조 스크립트입니다.

## 빠른 실행

저장소 루트에서 아래 명령으로 호스트 테스트를 실행할 수 있습니다.

```bash
./device/esp32/scripts/run_firmware_host_tests.sh
```

## 라즈베리파이 전송 방식 요약

현재 ESP32에서 Raspberry Pi로 넘기는 기본 전송 방식은 아래와 같습니다.

- 전송 매체: `USB Serial`
- 전송 형식: `JSON Lines(JSONL)` 한 줄당 패킷 1개
- 패킷 경계: 줄바꿈 문자 `\n`
- 기본 스키마 버전: `emg-glass.v1`
- 현재 기본 baud rate: `115200`
- 현재 기본 송신 주기: `20ms` 간격, 약 `50Hz`

즉, Raspberry Pi는 직렬 포트에서 한 줄씩 읽고, 그 한 줄을 JSON으로 파싱하는 구조를 기준으로 맞추면 됩니다.

참고 코드 위치:

- `device/esp32/firmware/src/transport_serial.cpp`
  - 현재 MVP 기준 Serial 전송 계층입니다.
- `device/esp32/firmware/src/packet.cpp`
  - `OutputPacket`을 JSONL 문자열로 바꾸는 코드입니다.
- `shared/protocol/esp32_pi_packet_format.md`
  - ESP32-Pi 공통 패킷 포맷 문서입니다.

참고:

- 지금 호스트 테스트에서는 실제 UART 대신 `stdout`으로 JSONL을 출력해 전송 흐름을 검증합니다.
- 실제 장비 연결 후에는 같은 형식을 유지한 채 ESP-IDF UART 출력으로 연결하면 됩니다.

## 라즈베리파이가 나중에 받게 될 패킷 필드 이름

ESP32는 처리 결과를 USB Serial 기준 JSONL 한 줄로 보냅니다.  
라즈베리파이는 아래 이름의 필드를 기준으로 데이터를 받게 됩니다.

- `schema`
- `seq`
- `timestamp_ms`
- `emg_ch1`
- `emg_ch2`
- `emg_ch3`
- `acc_x`
- `acc_y`
- `acc_z`
- `gyro_x`
- `gyro_y`
- `gyro_z`
- `state`
- `flags`
- `rep_index` (선택 필드)

패킷 포맷 상세 설명과 예시는 아래 문서를 기준으로 맞춥니다.

- `shared/protocol/esp32_pi_packet_format.md`

## 현재 검토 중인 EMG 센서 기준 반영 사항

- 대상 센서: `아두이노 근전도 EMG 모듈 KIT (건식 전극) [SZH-GJD001]`
- 이 센서는 초기 연동 시 **단일 아날로그 EMG 채널**로 보는 것이 안전합니다.
- 그래서 현재 코드에는 아래 파일이 추가되었습니다.
  - `device/esp32/firmware/include/sensor_analog_emg.h`
  - `device/esp32/firmware/src/sensor_analog_emg.cpp`
- 이 어댑터는
  - 센서 예제의 `500Hz` 샘플링 전제를 따라가고
  - 한 패킷 프레임 안에서 여러 ADC 샘플을 읽어
  - 우선 `emg_ch1` 에만 값을 넣는 구조입니다.
- 초기 실제 장착 단계에서는 `emg_ch2`, `emg_ch3` 를 `0` 으로 유지해도 됩니다.

## 실제 센서 연결 시 값이 안 잡힐 때 먼저 볼 것

SZH-GJD001 계열 센서는 판매처 예제가 아두이노 기준이라, ESP32에서 그대로 쓰면 값이 안 잡히거나 이상한 값이 나올 수 있습니다.

- `A0` 같은 아두이노 핀 이름을 ESP32에서 그대로 사용한 경우
  - ESP-IDF에서는 실제 ADC 가능 GPIO 번호로 바꿔야 합니다.
- ADC 설정이 빠진 경우
  - ADC 채널, 감쇠(attentuation), 해상도 전제가 맞지 않으면 값이 거의 0처럼 보일 수 있습니다.
- 센서 출력 영점이 중간 전압인데 이를 그대로 raw 값으로만 본 경우
  - baseline 보정 전에 값이 흔들리거나 이상하게 보일 수 있습니다.
- 전극 접촉 상태가 불안정한 경우
  - 건식 전극은 접촉 품질에 따라 값 편차가 큽니다.
- 아두이노 예제의 필터만 믿고 바로 `Serial.println(raw)` 식으로 본 경우
  - ESP32 쪽에서는 `sensor_analog_emg.cpp` -> `emg_filter.cpp` -> `calibration.cpp` 흐름까지 같이 봐야 합니다.

상세 점검 문서는 아래를 참고합니다.

- `docs/esp32_emg_sensor_bringup.md`

## 하드웨어 도착 후 교체 포인트

- `device/esp32/firmware/src/sensor_mock.cpp` `(실제 장착 후 변경 필요)`
  - 지금은 가짜 EMG/IMU 값을 생성합니다.
  - 실제 EMG/IMU 값을 읽는 코드로 교체해야 합니다.
- `device/esp32/firmware/src/sensor_analog_emg.cpp` `(실제 장착 후 우선 검토 대상)`
  - SZH-GJD001 계열 단일 아날로그 EMG 센서 기준 어댑터입니다.
  - 값이 안 잡히는 경우 가장 먼저 확인할 파일입니다.
  - 실제 ADC 핀, ADC 감쇠, 영점, 증폭 범위에 맞춰 수정해야 합니다.
- `device/esp32/firmware/include/sensor_source.h` `(실제 장착 후 구현체 연결 필요)`
  - 실센서 입력이 따라야 하는 공통 인터페이스입니다.
  - 인터페이스 자체는 유지하고, 이를 구현하는 실제 센서 어댑터를 추가하면 됩니다.
- `device/esp32/firmware/include/config.h` `(실제 장착 후 설정값 조정 필요)`
  - 샘플링 주기, threshold, smoothing 계수 같은 기본 설정이 들어 있습니다.
  - 실제 센서 노이즈와 장착 위치에 맞춰 수치를 조정할 가능성이 높습니다.
- `device/esp32/firmware/src/emg_filter.cpp` `(실제 장착 후 튜닝 가능성 높음)`
  - 이동평균, RMS, baseline 보정, 정규화, 활성 판정 로직이 들어 있습니다.
  - 실측 데이터 기준으로 윈도우 크기와 threshold를 조정할 수 있습니다.
- `device/esp32/firmware/src/calibration.cpp` `(실제 장착 후 튜닝 가능성 높음)`
  - rest baseline, MVC peak 보정 기준을 계산합니다.
  - 실제 사용자 데이터에 맞춰 샘플 개수나 보정 방식 수정이 필요할 수 있습니다.
- `shared/protocol/esp32_pi_packet_format.md` `(Pi 연동 시 검토 필요)`
  - 라즈베리파이와 맞춰야 하는 패킷 포맷 문서입니다.
  - 필드 이름은 유지하는 것이 좋지만, 팀 합의에 따라 확장 필드가 추가될 수 있습니다.

## 하드웨어 도착 후에도 유지 권장되는 부분

- `device/esp32/firmware/include/types.h`
  - EMG/IMU/출력 패킷 구조체 정의입니다.
- `device/esp32/firmware/src/packet.cpp`
  - `OutputPacket`을 JSONL 문자열로 바꾸는 코드입니다.
- `device/esp32/firmware/src/runtime_pipeline.cpp`
  - 센서 읽기 -> 처리 -> 패킷 생성 -> 송신 흐름을 묶는 중심 파일입니다.

핵심은 **전체 구조를 다시 짜는 것이 아니라, 센서 입력부와 튜닝 포인트만 교체하는 것**입니다.

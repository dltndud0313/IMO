# device/esp32

ESP32-S3 기반 센서 송신 코드를 관리하는 폴더입니다.

현재 들어 있는 코드는 **실제 EMG 센서와 IMU가 아직 도착하기 전**, 전체 데이터 흐름을 먼저 검증하기 위해 작성한 **mock 기반 사전 구현 코드**입니다.

즉, 지금 목표는 아래 흐름을 하드웨어 없이 먼저 고정하는 것입니다.

- 가짜 센서 입력 생성
- EMG 처리
- 캘리브레이션
- 상태머신 전이
- 패킷 생성
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

전송 계층은 **v1 JSONL 시도안을 archive로 보존하고, 실시간 경로는 v2 바이너리 프로토콜로 전환하는 방향**으로 정리합니다.

### 현재 코드에서 바로 확인되는 것

- 현재 실행 중인 펌웨어는 `emg-glass.v1` JSONL 패킷을 출력합니다.
- 즉, 어제 ESP32에서 본 `{...}` 한 줄 출력은 **v1 JSONL 송신 성공**입니다.
- 이 형식은 bring-up과 디버깅에는 유리하지만, 실시간 경로 최종안으로는 무겁습니다.

### 현재 기준 권장 전송 방식

- 전송 매체: `USB Serial`
- 전송 형식: `v2 binary frame`
- 프레임 경계: `magic + payload_len + crc16`
- 프로토콜 버전: `2`
- 현재 기본 baud rate: `115200`
- 현재 기본 송신 주기: `20ms` 간격, 약 `50Hz`

### v1 JSONL archive

- v1 문서: `shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`
- 용도: 사람이 직접 읽는 초기 디버깅, bring-up 참고
- 상태: archive

### v2 바이너리 설계 문서

- 현재 기준 문서: `shared/protocol/esp32_pi_packet_format.md`
- 변경 이유와 영향 범위: `docs/esp32_packet_protocol_migration.md`
- Raspberry Pi는 위 문서를 기준으로 **byte stream을 읽고 binary unpack** 하는 구조로 맞추는 것이 권장됩니다.
- 문자열 키 이름 대신 고정된 필드 순서와 상태 코드 표를 사용합니다.

### 포맷 선택 구조

- 현재 코드에는 `JSON_V1`, `BINARY_V2` 두 포맷이 모두 들어 있습니다.
- 기본 선택 위치: `device/esp32/firmware/include/config.h`
- 기본값: `kDefaultPacketFormat`
- 현재 기본값은 디버깅 편의를 위해 `JSON_V1` 입니다.
- 실시간성 비교 테스트 시에는 `BINARY_V2` 로 바꿔 같은 파이프라인을 비교할 수 있습니다.
- 이후 무선 경로(MQTT) 실험 시에도 `OutputPacket -> PacketBuffer` 구조를 그대로 재사용할 수 있습니다.

참고 코드 위치:

- `device/esp32/firmware/src/transport_serial.cpp`
  - 현재/후속 MVP 기준 Serial 전송 계층입니다.
- `device/esp32/firmware/src/packet.cpp`
  - `OutputPacket`을 wire format으로 바꾸는 계층입니다.
- `shared/protocol/esp32_pi_packet_format.md`
  - ESP32-Pi 공통 패킷 포맷 v2 문서입니다.

참고:

- 지금 호스트 테스트와 현재 펌웨어 출력은 실제 UART 대신 `stdout`/console로 v1 JSONL을 먼저 검증한 상태입니다.
- 실시간 경로 최종안은 v2 바이너리로 정리하되, v1 JSONL은 archive로 남겨 둡니다.

## v2로 바꾸는 이유와 예상 개선 폭

- JSONL은 디버깅이 쉽지만 문자열 생성/파싱 비용이 있습니다.
- 패킷 길이가 길어 `115200 baud` 에서 프레임 예산을 많이 차지합니다.
- v2 바이너리 프레임은 동일 정보량 기준 약 `38 bytes` 수준으로 설계합니다.

추정 비교:

- v1 JSON 예시 한 줄: 약 `228 bytes`
- v2 바이너리 프레임: 약 `38 bytes`
- 바이트 수 감소: 약 `83%`
- 동일 baud `115200` 기준 순수 전송 시간:
  - v1 JSON: 약 `19.8ms`
  - v2 Binary: 약 `3.3ms`

즉, 현재 `20ms` 주기에서는 **JSON은 전송 시간만으로 프레임 예산 대부분을 쓰지만**, v2 바이너리는 같은 baud rate에서도 훨씬 큰 여유를 확보합니다.

## 라즈베리파이가 나중에 받게 될 패킷 필드 이름

아래 항목은 **v1 JSONL archive 기준 필드 이름**입니다.  
기존 bring-up 로그와 문서를 읽을 때 참고용으로 유지합니다.

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

- `shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`

v2 바이너리에서는 위 문자열 필드 이름을 wire format에 직접 싣지 않습니다.  
대신 `seq`, `timestamp_ms`, 상태 코드, 스케일된 정수 payload 순서로 송신합니다.

## 패킷 필드 빠른 설명

- `schema`: 패킷 형식 버전 이름 문자열
  - 예: `"emg-glass.v1"`
- `seq`: 몇 번째로 보낸 패킷인지 나타내는 순번 정수
  - 예: `12`
- `timestamp_ms`: 데이터 생성 시각을 나타내는 밀리초 정수
  - 예: `240`
- `emg_ch1`: 1번 EMG 채널 값
  - 예: `0.53`
- `emg_ch2`: 2번 EMG 채널 값
  - 예: `0.00`
- `emg_ch3`: 3번 EMG 채널 값
  - 예: `0.00`
- `acc_x`: 가속도 X축 값
  - 예: `0.01`
- `acc_y`: 가속도 Y축 값
  - 예: `0.14`
- `acc_z`: 가속도 Z축 값
  - 예: `1.00`
- `gyro_x`: 자이로 X축 값
  - 예: `0.02`
- `gyro_y`: 자이로 Y축 값
  - 예: `0.03`
- `gyro_z`: 자이로 Z축 값
  - 예: `0.11`
- `state`: 현재 상태머신 상태 문자열
  - 예: `"STREAMING"`
- `flags`: mock 여부, calibration 완료 여부 같은 추가 상태 비트값
  - 예: `7`
- `rep_index`: 몇 번째 반복 운동인지 나타내는 선택 정수값
  - 예: `3`

## `state` 값 의미

- `IDLE`
  - 아직 캘리브레이션이나 스트리밍을 시작하지 않은 대기 상태
- `CALIBRATION_REST`
  - 힘을 주지 않은 휴식 상태 기준값을 수집하는 상태
- `CALIBRATION_MVC`
  - 최대 힘 기준값(MVC)을 수집하는 상태
- `READY`
  - 캘리브레이션이 끝나서 스트리밍 시작 준비가 된 상태
- `STREAMING`
  - 센서 처리 결과를 패킷으로 만들어 계속 전송하는 상태
- `ERROR`
  - 센서 이상이나 예외 상황이 발생한 오류 상태

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
- 즉, 현재 펌웨어 코드는 단순 mock만 있는 상태가 아니라 **SZH-GJD001 센서 기준 실센서 어댑터 뼈대도 함께 포함한 상태**입니다.
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
  - `OutputPacket`을 wire format으로 바꾸는 계층입니다.
- `device/esp32/firmware/src/runtime_pipeline.cpp`
  - 센서 읽기 -> 처리 -> 패킷 생성 -> 송신 흐름을 묶는 중심 파일입니다.

핵심은 **전체 구조를 다시 짜는 것이 아니라, 센서 입력부와 전송 계층만 교체하는 것**입니다.

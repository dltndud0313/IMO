# ESP32-Pi 패킷 포맷

이 문서는 **현재 기준 ESP32-Pi 직렬 통신 프로토콜**을 설명합니다.  
실시간 경로 최적화를 위해 기본 방향은 **v2 바이너리 프로토콜**입니다.

## 버전 현황

- `v1`: JSON Lines(JSONL) 텍스트 패킷
  - 상태: archive
  - 용도: 초기 bring-up, 사람이 직접 읽는 디버깅
  - 문서: `shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`
- `v2`: 바이너리 패킷
  - 상태: 설계 기준
  - 용도: 실시간 전송, Raspberry Pi 수신기 연동
  - 권장 여부: **권장**

## 왜 v2 바이너리로 전환하나

기존 v1 JSONL은 디버깅에는 편하지만, 실시간 경로에서는 아래 한계가 분명합니다.

- ESP32에서 문자열 생성 비용이 듭니다.
- Raspberry Pi에서 JSON 파싱 비용이 듭니다.
- 패킷 길이가 길어 Serial 대역폭을 많이 사용합니다.
- 줄바꿈 기반 framing은 사람이 보기 쉽지만, 저지연 전송 최적화에는 불리합니다.

따라서 **센서 처리 파이프라인은 유지하고, 전송 계층만 바이너리로 교체**하는 방향으로 정리합니다.

## 예상 개선 효과

아래 수치는 현재 JSON 예시 패킷과 v2 바이너리 센서 프레임 설계를 비교한 **추정치**입니다.

- v1 JSON 예시 한 줄 길이: 약 `228 bytes`
- v2 바이너리 프레임 길이: 약 `38 bytes`
- 바이트 수 감소: 약 `83%` 감소
- 동일 baud `115200` 기준 순수 전송 시간:
  - v1 JSON: 약 `19.8ms`
  - v2 Binary: 약 `3.3ms`
- 추정 전송 시간 차이: 약 `16.5ms` 감소

즉, 현재 20ms 주기에서는 **JSON이 프레임 예산 대부분을 사용하지만**, v2 바이너리는 같은 baud rate에서도 훨씬 큰 여유를 확보할 수 있습니다.

## 전송 원칙

- 전송 매체: `USB Serial`
- 전송 형식: `binary frame`
- 엔디안: `little-endian`
- 문자열 필드는 wire packet에 직접 넣지 않습니다.
- `struct` 메모리 덤프를 그대로 보내지 않습니다.
- ESP32/Pi 모두 **명시적 pack/unpack 함수**로 직렬화합니다.

## 프레임 구조 (v2)

### Header

| 필드 | 타입 | 크기 | 설명 |
| --- | --- | --- | --- |
| `magic` | `uint16_t` | 2 | 프레임 시작 식별값, `0x454D` (`'EM'`) |
| `version` | `uint8_t` | 1 | 프로토콜 버전, 현재 `2` |
| `packet_type` | `uint8_t` | 1 | 패킷 종류, 센서 프레임은 `1` |
| `payload_len` | `uint16_t` | 2 | payload 길이, 현재 센서 프레임은 `30` |

### Payload

| 필드 | 타입 | 크기 | 설명 |
| --- | --- | --- | --- |
| `seq` | `uint32_t` | 4 | 송신 순번 |
| `timestamp_ms` | `uint32_t` | 4 | ESP32 기준 밀리초 타임스탬프 |
| `emg_ch1` | `int16_t` | 2 | 정규화 EMG 채널 1, `0.0~1.0` 을 `0~1000`으로 스케일 |
| `emg_ch2` | `int16_t` | 2 | 정규화 EMG 채널 2, 초기 단일채널 단계에서는 `0` 가능 |
| `emg_ch3` | `int16_t` | 2 | 정규화 EMG 채널 3, 초기 단일채널 단계에서는 `0` 가능 |
| `acc_x` | `int16_t` | 2 | 가속도 X축, 실수값에 `1000` 스케일 적용 |
| `acc_y` | `int16_t` | 2 | 가속도 Y축, 실수값에 `1000` 스케일 적용 |
| `acc_z` | `int16_t` | 2 | 가속도 Z축, 실수값에 `1000` 스케일 적용 |
| `gyro_x` | `int16_t` | 2 | 자이로 X축, 실수값에 `1000` 스케일 적용 |
| `gyro_y` | `int16_t` | 2 | 자이로 Y축, 실수값에 `1000` 스케일 적용 |
| `gyro_z` | `int16_t` | 2 | 자이로 Z축, 실수값에 `1000` 스케일 적용 |
| `state` | `uint8_t` | 1 | 상태머신 상태 코드 |
| `flags` | `uint8_t` | 1 | mock/calibration/motion 상태 비트 필드 |
| `rep_index` | `int16_t` | 2 | 반복 횟수, 값이 없으면 `-1` |

### Tail

| 필드 | 타입 | 크기 | 설명 |
| --- | --- | --- | --- |
| `crc16` | `uint16_t` | 2 | 헤더+payload 기준 CRC16 |

### 총 길이

- Header `6 bytes`
- Payload `30 bytes`
- Tail `2 bytes`
- 총합 `38 bytes`

## 상태 코드 정의

| 값 | 상태 |
| --- | --- |
| `0` | `IDLE` |
| `1` | `CALIBRATION_REST` |
| `2` | `CALIBRATION_MVC` |
| `3` | `READY` |
| `4` | `STREAMING` |
| `5` | `ERROR` |

## 단일채널 EMG 센서 사용 시 주의

- 현재 검토 중인 `SZH-GJD001` 계열 센서는 단일 아날로그 EMG 채널 전제를 우선 사용합니다.
- 초기 하드웨어 연동 단계에서는
  - `emg_ch1`에 실제 EMG 처리값을 넣고
  - `emg_ch2`, `emg_ch3`는 `0` 으로 유지할 수 있습니다.
- Raspberry Pi 수신기는 위 상황도 정상 프레임으로 받아들이도록 구현하는 것이 안전합니다.

## Raspberry Pi 수신 기준

Raspberry Pi 수신기는 아래 규칙을 기준으로 ESP32 패킷을 읽습니다.

- 입력 경로: USB Serial byte stream
- 프레임 시작: `magic == 0x454D`
- 프로토콜 버전: `version == 2`
- packet type: `1`
- payload 길이 검증: `30`
- CRC16 검증 실패 시 폐기
- 잘못된 프레임이 들어와도 전체 수신 루프는 멈추지 않고 다음 프레임을 계속 찾음

Pi 쪽은 이 문서의 상태 코드와 스케일 규칙을 그대로 기준으로 구현합니다.

## v1과 달라지는 점

- `schema` 문자열은 wire packet에서 제거됩니다.
- `state` 문자열은 `uint8_t` 코드로 바뀝니다.
- `rep_index`는 optional 대신 `-1` sentinel을 사용합니다.
- JSON 키 이름 대신 **고정 필드 순서**를 사용합니다.

## 변경 범위

바이너리 전환 시 **센서 처리 로직 전체를 다시 짜는 것은 아닙니다.**  
주요 변경 범위는 아래와 같습니다.

- 변경 대상:
  - `device/esp32/firmware/include/packet.h`
  - `device/esp32/firmware/src/packet.cpp`
  - `device/esp32/firmware/include/transport_serial.h`
  - `device/esp32/firmware/src/transport_serial.cpp`
  - `device/esp32/firmware/include/types.h` 일부
  - `device/esp32/firmware/src/runtime_pipeline.cpp` 일부
- 유지 대상:
  - `sensor_mock.cpp`
  - `sensor_analog_emg.cpp`
  - `emg_filter.cpp`
  - `imu_processor.cpp`
  - `calibration.cpp`
  - `state_machine.cpp`

## 코드 위치

- 송신 타입 정의: `device/esp32/firmware/include/types.h`
- 직렬화 계층: `device/esp32/firmware/src/packet.cpp`
- Serial 송신: `device/esp32/firmware/src/transport_serial.cpp`
- 이전 JSONL 문서 archive: `shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`

# ESP32-Pi 패킷 포맷 (Current)

현재 실시간 경로 기준은 `BINARY_V2` 고정 길이 프레임입니다.

## 핵심 규칙

- 전송 매체: USB Serial
- 엔디안: little-endian
- 프레임 길이: `64 bytes` 고정
- 문자열 상태값 대신 상태 코드를 사용
- ESP32는 캘리브레이션 없이 센서 수집/전송에 집중

## 프레임 레이아웃 (`64 bytes`)

### Header (`6 bytes`)

| 필드 | 타입 | 크기 | 값 |
| --- | --- | --- | --- |
| `magic` | `uint16` | 2 | `0x454D` (`'ME'`) |
| `version` | `uint8` | 1 | `2` |
| `packet_type` | `uint8` | 1 | `1` (sensor frame) |
| `payload_len` | `uint16` | 2 | `56` |

### Payload (`56 bytes`)

| 필드 | 타입 | 크기 | 설명 |
| --- | --- | --- | --- |
| `seq` | `uint32` | 4 | 송신 순번 |
| `timestamp_ms` | `uint32` | 4 | ESP32 기준 타임스탬프 |
| `emg[4]` | `int16 x4` | 8 | EMG 4채널, `value * 1000` 스케일 |
| `imu[3].accel[3]` | `int16 x9` | 18 | IMU 3개 가속도, `value * 1000` |
| `imu[3].gyro[3]` | `int16 x9` | 18 | IMU 3개 자이로, `value * 100` |
| `state` | `uint8` | 1 | 상태 코드 |
| `flags` | `uint8` | 1 | 상태 비트 |
| `rep_index` | `int16` | 2 | 없으면 `-1` |

### Tail (`2 bytes`)

| 필드 | 타입 | 크기 | 설명 |
| --- | --- | --- | --- |
| `crc16` | `uint16` | 2 | Header+Payload CRC16-CCITT-FALSE |

## 상태 코드

| 코드 | 의미 |
| --- | --- |
| `0` | `IDLE` |
| `1` | `STREAMING` |
| `2` | `ERROR` |

## flags 비트

| 비트 | 마스크 | 의미 |
| --- | --- | --- |
| bit0 | `0x01` | mock 데이터 |
| bit1 | `0x02` | IMU bias 준비 완료(3개 모두) |
| bit2 | `0x04` | motion 감지 |
| bit3 | `0x08` | IMU 일부만 준비됨 |

## Pi 파서 체크리스트

1. `magic/version/type/payload_len` 검증
2. `64 bytes` 단위 프레임 추출
3. CRC16 검증 실패 프레임 폐기
4. 스케일 역변환
- EMG/accel: `/1000`
- gyro: `/100`

## 참고 구현

- ESP32 인코더/디코더:
  - `device/esp32/firmware/src/packet.cpp`
- Pi 실시간 디코더:
  - `device/esp32/scripts/decode_binary_sensor_stream.py`

# device/raspberry-pi

Raspberry Pi 수신기, 로그 저장, 후속 처리 코드를 두는 폴더입니다.

현재 이 저장소에는 Pi 수신기 구현 코드가 아직 들어 있지 않습니다.  
대신 **ESP32가 어떤 형식으로 보내는지**, **Pi가 무엇을 기준으로 받아야 하는지**는 문서로 정리되어 있습니다.

## 먼저 볼 문서 순서

1. `../esp32/README.md`
   - 전체 흐름, 현재 기본 포맷, JSON/BINARY 선택 구조
2. `../../shared/protocol/esp32_pi_packet_format.md`
   - **Pi 구현 기준 문서**
   - v2 바이너리 프레임 구조, 상태 코드, 스케일 규칙
3. `../../shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`
   - 초기 JSONL 로그를 읽거나 bring-up 디버깅할 때 참고

## 현재 기준

- ESP32 기본 송신 매체: `USB Serial`
- 포맷 선택 구조:
  - `JSON_V1`
  - `BINARY_V2`
- 현재 펌웨어 기본값: `JSON_V1`
- 실시간 경로 권장값: `BINARY_V2`

즉, Pi 수신기는 두 포맷을 모두 이해하면 가장 좋고, 최소한 현재 bring-up 단계에서는 JSON 로그를 읽을 수 있어야 합니다.

## Pi 쪽 최소 요구사항

### JSON_V1 수신기

- Serial에서 한 줄씩 읽기
- UTF-8 문자열 decode
- JSON parse
- 필수 필드 검증
- 로그 저장/표시

### BINARY_V2 수신기

- Serial에서 byte stream 읽기
- `magic == 0x454D` 찾기
- header(`magic`, `version`, `packet_type`, `payload_len`) 검증
- payload 길이만큼 읽기
- `crc16` 검증
- little-endian unpack
- 상태 코드와 스케일 규칙 적용

## v2 바이너리 구현 체크리스트

- `magic`: `0x454D`
- `version`: `2`
- `packet_type`: `1`
- `payload_len`: `30`
- 전체 프레임 길이: `38 bytes`
- endian: `little-endian`
- `state`: `uint8_t` 코드
- `rep_index == -1` 이면 값 없음
- `emg_ch*`: `0~1000` 스케일 -> `1000.0`으로 나눠 복원
- `acc_*`, `gyro_*`: `1000` 스케일 -> `1000.0`으로 나눠 복원

## Python 구현 시작점 예시

바이너리 v2 기준으로는 Python 표준 라이브러리 `struct`만으로 시작할 수 있습니다.

```python
import struct

HEADER_FMT = "<HBBH"
PAYLOAD_FMT = "<IIhhhhhhhhhBBh"
CRC_FMT = "<H"

HEADER_SIZE = struct.calcsize(HEADER_FMT)   # 6
PAYLOAD_SIZE = struct.calcsize(PAYLOAD_FMT) # 30
CRC_SIZE = struct.calcsize(CRC_FMT)         # 2
FRAME_SIZE = HEADER_SIZE + PAYLOAD_SIZE + CRC_SIZE  # 38
```

상태 코드는 아래를 기준으로 매핑합니다.

- `0`: `IDLE`
- `1`: `CALIBRATION_REST`
- `2`: `CALIBRATION_MVC`
- `3`: `READY`
- `4`: `STREAMING`
- `5`: `ERROR`

## 실무적으로 권장하는 진행 순서

1. 먼저 JSON_V1로 Serial 수신기 뼈대 확인
2. 그 다음 v2 바이너리 unpack 추가
3. 같은 로그/렌더 경로에 두 포맷을 선택형으로 연결
4. 실제 센서 도착 후 JSON/BINARY 지연과 누락률 비교
5. 이후 MQTT 같은 무선 경로 실험 시에도 `BINARY_V2` payload 재사용

## 주의

- C 구조체 메모리를 그대로 받는다고 가정하면 안 됩니다.
- 반드시 `shared/protocol/esp32_pi_packet_format.md` 문서 기준으로 unpack 해야 합니다.
- ESP32 기본 포맷이 바뀌면 Pi 쪽 기본 수신 포맷도 같이 맞춰야 합니다.

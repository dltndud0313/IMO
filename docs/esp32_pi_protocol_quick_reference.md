# ESP32-Pi 프로토콜 한눈에 보기

이 문서는 ESP32-Pi 직렬 통신에서 **무슨 포맷이 있고**, **지금 기본값이 무엇이고**, **어떤 문서를 기준으로 구현해야 하는지**를 한 번에 보기 위한 요약 문서입니다.

## 지금 결론

- 구현은 `JSON_V1`, `BINARY_V2` 두 포맷을 모두 지원합니다.
- 현재 ESP32 기본 포맷: `JSON_V1`
- 실시간 경로 권장 포맷: `BINARY_V2`
- Pi 구현 기준 문서: `shared/protocol/esp32_pi_packet_format.md`

## 포맷 비교

| 항목 | JSON_V1 | BINARY_V2 |
| --- | --- | --- |
| 목적 | bring-up, 사람이 읽는 디버깅 | 실시간 전송, 성능 비교, 실제 운영 |
| 경계 구분 | 줄바꿈 `\n` | `magic + payload_len + crc16` |
| 파싱 방식 | UTF-8 decode + JSON parse | byte stream unpack |
| 상태 표현 | 문자열 (`"STREAMING"`) | `uint8_t` 상태 코드 |
| 패킷 길이 | 예시 약 `228 bytes` | 고정 `38 bytes` |
| 장점 | 바로 읽기 쉬움, 디버깅 쉬움 | 가볍고 빠름, 대역폭 절약 |
| 단점 | 문자열 생성/파싱 비용 큼 | 사람이 바로 읽기 어려움 |
| Pi 구현 난이도 | 낮음 | 중간 |
| 현재 사용성 | 바로 사용 가능 | 바로 사용 가능 |

## 현재 구현 상태

- ESP32 mock 출력으로 `JSON_V1` 확인 완료
- JSON/BINARY 선택형 직렬화 구조 구현 완료
- 호스트 테스트 통과 완료
- Pi 수신기 코드는 아직 저장소에 없음

즉, **ESP32 쪽은 두 포맷 모두 준비됐고**, Pi 쪽은 이 문서를 기준으로 수신기만 구현하면 됩니다.

## 기본값과 변경 위치

- 기본 포맷 설정 파일:
  - `device/esp32/firmware/include/config.h`
- 설정 상수:
  - `kDefaultPacketFormat`

현재 기본값은 디버깅 편의를 위해 `JSON_V1` 입니다.  
실시간 비교 테스트를 하려면 이 값을 `BINARY_V2`로 바꾸면 됩니다.

## 포맷별 실행 방법

현재 포맷 선택은 **컴파일 타임 선택**입니다.  
즉, `config.h`에서 값을 바꾼 뒤 다시 `build -> flash` 해야 합니다.

### 1. JSON_V1 실행

`device/esp32/firmware/include/config.h`에서:

```cpp
inline constexpr PacketFormat kDefaultPacketFormat = PacketFormat::JSON_V1;
```

그다음:

```bash
cd ~/S14P31C203/device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyACM0 -b 115200 flash monitor
```

정상이라면 사람이 읽을 수 있는 JSON 한 줄이 계속 출력됩니다.

### 2. BINARY_V2 실행

`device/esp32/firmware/include/config.h`에서:

```cpp
inline constexpr PacketFormat kDefaultPacketFormat = PacketFormat::BINARY_V2;
```

그다음:

```bash
cd ~/S14P31C203/device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyACM0 -b 115200 flash
```

바이너리는 사람이 읽는 문자열이 아니므로 `monitor` 대신 raw bytes 확인이 더 적합합니다.

```bash
stty -F /dev/ttyACM0 115200 raw -echo
dd if=/dev/ttyACM0 bs=38 count=1 status=none | xxd -g1
```

### 3. 포트 먼저 확인

환경에 따라 포트가 `/dev/ttyUSB0` 또는 `/dev/ttyACM0`로 바뀔 수 있습니다.

```bash
ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
```

### 4. 종료 방법

- `idf.py monitor` 종료:
  - `Ctrl + ]`

## Raspberry Pi 담당자가 보는 순서

1. `device/raspberry-pi/README.md`
2. `shared/protocol/esp32_pi_packet_format.md`
3. 필요하면 `shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`

## 언제 어떤 포맷을 쓰는가

### JSON_V1

이럴 때 씁니다.

- 센서 bring-up 초기
- 사람이 직접 로그를 읽고 싶을 때
- 필드 이름 기반 디버깅이 필요할 때

### BINARY_V2

이럴 때 씁니다.

- 실시간성 비교
- Serial 대역폭 절감
- 추후 MQTT 같은 무선 경로 payload 재사용
- 실제 운영 경로 검토

## 관련 문서 위치

- 전체 개요: `device/esp32/README.md`
- Pi 시작 문서: `device/raspberry-pi/README.md`
- v2 상세 프로토콜: `shared/protocol/esp32_pi_packet_format.md`
- v1 JSON archive: `shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`
- 전환 이유/영향 범위: `docs/esp32_packet_protocol_migration.md`

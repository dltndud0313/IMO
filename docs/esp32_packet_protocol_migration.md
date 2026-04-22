# ESP32 패킷 프로토콜 전환 메모

이 문서는 ESP32-Pi 직렬 통신을 v1 JSONL에서 v2 바이너리로 전환하는 이유와 영향을 정리한 문서입니다.

빠른 비교와 현재 기본값은 `docs/esp32_pi_protocol_quick_reference.md`에서 먼저 볼 수 있습니다.

## 변경 이유

기존 v1 JSONL은 아래 장점이 있었습니다.

- 사람이 직접 읽기 쉽다.
- bring-up과 디버깅이 쉽다.
- Python 수신기 초기 구현이 단순하다.

하지만 실시간 경로에서는 다음 한계가 명확합니다.

- ESP32에서 문자열 생성 비용이 든다.
- Raspberry Pi에서 JSON 파싱 비용이 든다.
- 패킷 길이가 길어 Serial 대역폭을 과도하게 사용한다.
- 현재 `20ms` 주기 기준으로 전송 시간 예산이 너무 빡빡하다.

## 변경 범위

### 그대로 유지하는 부분

- `sensor_mock.cpp`
- `sensor_analog_emg.cpp`
- `emg_filter.cpp`
- `imu_processor.cpp`
- `calibration.cpp`
- `state_machine.cpp`

즉, **센서 생성/처리/상태 전이 로직은 유지**합니다.

### 주로 바뀌는 부분

- `device/esp32/firmware/include/packet.h`
- `device/esp32/firmware/src/packet.cpp`
- `device/esp32/firmware/include/transport_serial.h`
- `device/esp32/firmware/src/transport_serial.cpp`
- `device/esp32/firmware/include/types.h` 일부
- `device/esp32/firmware/src/runtime_pipeline.cpp` 일부

즉, **직렬화와 송신 계층 중심 변경**입니다.

## 예상 개선 폭

현재 JSON 예시 한 줄을 기준으로 비교하면:

- v1 JSON: 약 `228 bytes`
- v2 Binary: 약 `38 bytes`
- 감소 폭: 약 `83%`

동일 baud `115200` 기준 순수 전송 시간은 대략:

- v1 JSON: 약 `19.8ms`
- v2 Binary: 약 `3.3ms`

즉, 같은 송신 주기 `20ms`에서도 바이너리 전환 후 훨씬 큰 여유를 확보할 수 있습니다.

## 보존 정책

- v1 JSONL 문서는 삭제하지 않습니다.
- `shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`로 보존합니다.
- v2는 `shared/protocol/esp32_pi_packet_format.md`를 기준 문서로 사용합니다.

## Raspberry Pi 쪽 영향

- Pi 수신기는 JSON 라인 파싱 대신 byte stream unpack으로 바뀝니다.
- 문자열 필드 대신 상태 코드와 스케일된 정수 payload를 기준으로 구현합니다.
- 따라서 Pi 수신기 담당자는 반드시 v2 문서를 기준으로 구현해야 합니다.

## 구현 원칙

- `struct memcpy` 방식 금지
- little-endian 고정
- `magic + payload_len + crc16` 프레임 구조 사용
- 상태는 문자열 대신 `uint8_t` 코드 사용
- `rep_index`는 `-1` sentinel 사용

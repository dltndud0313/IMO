# ESP32 펌웨어 구조

이 문서는 팀 저장소 최신 구조에서 ESP32 담당자가 주로 봐야 하는 폴더를 설명합니다.

## 위치

- `device/esp32/firmware/`
  - 실제 ESP-IDF 프로젝트 루트
- `device/esp32/scripts/`
  - Ubuntu 22.04 호스트 검증 스크립트
- `shared/protocol/esp32_pi_packet_format.md`
  - Raspberry Pi와 공유하는 v2 바이너리 패킷 포맷 문서
- `shared/protocol/archive/esp32_pi_packet_format_v1_jsonl.md`
  - 초기 시도안이었던 v1 JSONL archive 문서

## 핵심 흐름

1. `sensor_mock.cpp` 또는 실제 센서 어댑터가 샘플 생성
2. `emg_filter.cpp`가 EMG 값을 처리
3. `calibration.cpp`가 rest baseline / MVC peak 기준값 생성
4. `state_machine.cpp`가 상태 전이 관리
5. `runtime_pipeline.cpp`가 최종 `OutputPacket` 생성
6. `packet.cpp`가 wire format으로 직렬화
7. `transport_serial.cpp`가 Serial로 송신

## 전송 계층 변경 이유

센서 처리 파이프라인은 유지하고, 전송 계층만 v1 JSONL에서 v2 바이너리로 전환하는 방향으로 정리합니다.

이유:

- JSON 문자열 생성 비용이 ESP32에서 불필요하게 큽니다.
- Raspberry Pi에서 JSON 파싱 비용이 듭니다.
- `115200 baud` 기준으로 JSON 패킷 길이가 너무 깁니다.
- 실시간 경로에서는 사람이 읽기 쉬운 포맷보다 전송 비용이 더 중요합니다.

추정 비교:

- v1 JSON 예시 한 줄: 약 `228 bytes`
- v2 binary 프레임: 약 `38 bytes`
- 바이트 수 감소: 약 `83%`
- 동일 baud 기준 순수 전송 시간:
  - v1 JSON: 약 `19.8ms`
  - v2 Binary: 약 `3.3ms`

## 하드웨어 도착 후 바뀌는 파일

- `device/esp32/firmware/src/sensor_mock.cpp` `(실제 장착 후 변경 필요)`
- `device/esp32/firmware/src/sensor_analog_emg.cpp` `(실제 장착 후 우선 검토 대상)`
- `device/esp32/firmware/include/sensor_source.h` `(실제 장착 후 구현체 추가)`
- `device/esp32/firmware/include/config.h` `(실제 장착 후 수치 튜닝 가능성 높음)`
- `device/esp32/firmware/src/emg_filter.cpp` `(실제 장착 후 수치 튜닝 가능성 높음)`
- `device/esp32/firmware/src/calibration.cpp` `(실제 장착 후 수치 튜닝 가능성 높음)`

## SZH-GJD001 실센서 연동 시 체크 포인트

- 이 센서는 판매처 예제가 아두이노 코드(`analogRead(A0)`) 기준이라 ESP-IDF에 그대로 넣으면 안 됩니다.
- ESP32에서는 `A0` 대신 실제 ADC 가능 GPIO와 ESP-IDF ADC 설정을 사용해야 합니다.
- 값이 아예 안 나오거나 0에 가깝게 나오면 아래 순서로 확인합니다.
  1. `sensor_analog_emg.cpp`의 ADC 읽기 연결 여부
  2. ADC 핀/감쇠/전압 범위 설정
  3. 전극 접촉 상태
  4. baseline 보정 전 raw 값의 중심 전압
  5. `emg_filter.cpp`, `calibration.cpp`의 튜닝 값

상세 문서:
- `docs/esp32_emg_sensor_bringup.md`

## 유지해야 하는 파일

- `device/esp32/firmware/include/types.h`
- `device/esp32/firmware/src/packet.cpp`
- `shared/protocol/esp32_pi_packet_format.md`

패킷 포맷은 Raspberry Pi 수신기와 직접 맞물리므로, 이 세 영역은 임의 변경하지 않고 문서 기준으로 함께 바꾸는 편이 안전합니다.

## v1 보존 범위

- v1 JSONL은 삭제하지 않고 `shared/protocol/archive/` 아래 보존합니다.
- bring-up 로그, 초기 디버깅, 기존 설명 문서 참조는 계속 가능합니다.
- 실제 구현 기준은 v2 바이너리 문서를 우선합니다.

추가 참고:

- `docs/esp32_packet_protocol_migration.md`
  - 전환 이유, 변경 범위, 예상 개선 폭 정리

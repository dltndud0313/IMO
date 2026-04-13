# ESP32 펌웨어 구조

이 문서는 팀 저장소 최신 구조에서 ESP32 담당자가 주로 봐야 하는 폴더를 설명합니다.

## 위치

- `device/esp32/firmware/`
  - 실제 ESP-IDF 프로젝트 루트
- `device/esp32/scripts/`
  - Ubuntu 22.04 호스트 검증 스크립트
- `shared/protocol/esp32_pi_packet_format.md`
  - Raspberry Pi와 공유하는 패킷 포맷 문서

## 핵심 흐름

1. `sensor_mock.cpp` 또는 실제 센서 어댑터가 샘플 생성
2. `emg_filter.cpp`가 EMG 값을 처리
3. `calibration.cpp`가 rest baseline / MVC peak 기준값 생성
4. `state_machine.cpp`가 상태 전이 관리
5. `runtime_pipeline.cpp`가 최종 `OutputPacket` 생성
6. `transport_serial.cpp`가 JSONL 패킷을 송신

## 하드웨어 도착 후 바뀌는 파일

- `device/esp32/firmware/src/sensor_mock.cpp` `(실제 장착 후 변경 필요)`
- `device/esp32/firmware/include/sensor_source.h` `(실제 장착 후 구현체 추가)`
- `device/esp32/firmware/include/config.h` `(실제 장착 후 수치 튜닝 가능성 높음)`
- `device/esp32/firmware/src/emg_filter.cpp` `(실제 장착 후 수치 튜닝 가능성 높음)`
- `device/esp32/firmware/src/calibration.cpp` `(실제 장착 후 수치 튜닝 가능성 높음)`

## 유지해야 하는 파일

- `device/esp32/firmware/include/types.h`
- `device/esp32/firmware/src/packet.cpp`
- `shared/protocol/esp32_pi_packet_format.md`

패킷 포맷이 바뀌면 Raspberry Pi 수신기도 같이 수정해야 하므로, 이 세 영역은 임의 변경하지 않는 편이 안전합니다.

# firmware/

ESP32-S3(ESP-IDF)용 펌웨어 뼈대입니다.  
핵심 목적은 하드웨어가 없어도 `가짜 센서 -> 처리 -> 패킷` 흐름을 먼저 검증하는 것입니다.

## 하위 폴더

- `include/`: 공용 타입, 인터페이스, 설정값
- `src/`: 실제 로직 구현
- `main/`: ESP-IDF 진입점(`app_main`)
- `tests/`: Ubuntu 호스트 기반 C++ 테스트
- `tools/`: 가짜 패킷 발생기 같은 보조 실행 파일

## 빠른 검증

```bash
./device/esp32/scripts/run_firmware_host_tests.sh
```

## 하드웨어 도착 후 교체

- `src/sensor_mock.cpp` `(실제 장착 후 변경 필요)`
  - mock 입력을 실제 센서 입력 코드로 교체
- `include/config.h` `(실제 장착 후 설정값 조정 필요)`
  - threshold, 샘플링 주기, smoothing 계수 튜닝
- `src/emg_filter.cpp`, `src/calibration.cpp` `(실제 장착 후 튜닝 가능성 높음)`
  - 실측 데이터 기준으로 EMG 처리 파라미터 조정
- 패킷 스키마(`emg-glass.v1`)는 Pi와의 호환을 위해 유지 권장

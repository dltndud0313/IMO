# firmware/

ESP32-S3(ESP-IDF)용 펌웨어 뼈대입니다.  
핵심 목적은 하드웨어가 없어도 `가짜 센서 -> 처리 -> 패킷` 흐름을 먼저 검증하는 것입니다.

현재는 mock 파이프라인과 함께, `SZH-GJD001` 계열 단일 아날로그 EMG 센서를 염두에 둔
실센서 어댑터 뼈대(`src/sensor_analog_emg.cpp`)도 같이 포함되어 있습니다.

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

## 빠르게 봐야 할 문서 기준

- 패킷 필드 이름과 예시값
  - `../README.md`
- `state` 값 의미
  - `../README.md`
- ESP32-Pi 공통 패킷 포맷
  - `../../shared/protocol/esp32_pi_packet_format.md`

## 하드웨어 도착 후 교체

- `src/sensor_mock.cpp` `(실제 장착 후 변경 필요)`
  - mock 입력을 실제 센서 입력 코드로 교체
- `src/sensor_analog_emg.cpp` `(실제 장착 후 우선 검토 대상)`
  - SZH-GJD001 계열 단일 아날로그 EMG 센서를 ESP32 ADC에 연결할 때 먼저 보는 파일
  - 센서 예제의 500Hz band-pass 필터 아이디어를 옮겨둔 어댑터
- `include/config.h` `(실제 장착 후 설정값 조정 필요)`
  - threshold, 샘플링 주기, smoothing 계수 튜닝
- `src/emg_filter.cpp`, `src/calibration.cpp` `(실제 장착 후 튜닝 가능성 높음)`
  - 실측 데이터 기준으로 EMG 처리 파라미터 조정
- 패킷 스키마(`emg-glass.v1`)는 Pi와의 호환을 위해 유지 권장
- 패킷 필드 이름(`schema`, `emg_ch1`, `state` 등)도 Pi 파서와 맞물리므로 현재 이름 유지 권장

## SZH-GJD001 센서 기준 수정 순서

1. `src/sensor_analog_emg.cpp`
   - `read_raw_sample()`에 ESP-IDF ADC 읽기 코드를 연결
2. `main/main.cpp`
   - `MockSensorSource` 대신 실제 센서 어댑터를 연결
3. `include/config.h`
   - 샘플 수, ADC full scale, threshold 조정
4. `src/emg_filter.cpp`
   - 실제 센서 노이즈에 맞춰 RMS / 이동평균 / threshold 튜닝
5. `src/calibration.cpp`
   - rest / MVC 기준이 실제 사용자 데이터에 맞는지 확인

값이 안 잡히면 가장 먼저 `src/sensor_analog_emg.cpp`와 ADC 핀 설정부터 확인하는 것이 좋습니다.

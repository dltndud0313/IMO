# ESP32 EMG Sensor Bring-Up

이 문서는 `SZH-GJD001` 계열 단일 아날로그 EMG 센서를 ESP32에 실제로 붙일 때, 값이 안 잡히는 문제를 줄이기 위한 점검 문서입니다.

## 전제

- 센서: `아두이노 근전도 EMG 모듈 KIT (건식 전극) [SZH-GJD001]`
- 현재 코드 구조:
  - `device/esp32/firmware/src/sensor_analog_emg.cpp`
  - `device/esp32/firmware/src/emg_filter.cpp`
  - `device/esp32/firmware/src/calibration.cpp`
  - `device/esp32/firmware/src/runtime_pipeline.cpp`

## 왜 판매처 예제를 그대로 쓰면 안 되는가

판매처 예제는 아두이노 스타일 코드입니다.

- `setup()`, `loop()`
- `analogRead(A0)`
- `Serial.println(...)`

우리 프로젝트는 ESP-IDF 기준이므로, 아래를 직접 맞춰야 합니다.

- ADC 핀 번호
- ADC 읽기 API
- 샘플링 방식
- 패킷 송신 방식

즉, 예제는 참고용이고 그대로 복사해서 끝나는 구조가 아닙니다.

## 값이 안 잡히는 대표 원인

1. `A0` 같은 핀 이름을 그대로 사용한 경우
   - ESP32에서는 보드별 ADC 가능 GPIO를 확인해야 합니다.
2. ADC 설정이 빠진 경우
   - 감쇠(attentuation)나 채널 설정이 맞지 않으면 값 범위가 비정상일 수 있습니다.
3. 센서 출력 영점을 고려하지 않은 경우
   - raw ADC 값이 중간값 근처를 중심으로 흔들릴 수 있습니다.
4. 건식 전극 접촉이 불안정한 경우
   - 피부 접촉 상태에 따라 값이 매우 달라질 수 있습니다.
5. 필터/정규화 파라미터가 mock 기준인 경우
   - 실센서 노이즈는 mock보다 훨씬 거칠 수 있습니다.

## 실제 장착 후 가장 먼저 수정할 파일

### 1. `device/esp32/firmware/src/sensor_analog_emg.cpp`

가장 먼저 확인할 파일입니다.

- `read_raw_sample()`에 실제 ESP-IDF ADC 읽기 코드 연결
- 실제 ADC 핀과 감쇠 설정 반영
- 센서 원시값이 어느 범위로 들어오는지 확인

현재는 placeholder 형태라 실제 장착 후 반드시 수정해야 합니다.

### 2. `device/esp32/firmware/main/main.cpp`

- `MockSensorSource` 대신 실제 센서 어댑터 연결
- 필요하면 IMU 어댑터도 함께 연결

### 3. `device/esp32/firmware/include/config.h`

- 샘플링 주기
- 한 프레임당 샘플 수
- ADC full scale
- 활성 threshold

실센서 기준으로 다시 조정할 가능성이 높습니다.

### 4. `device/esp32/firmware/src/emg_filter.cpp`

- 이동평균 창 크기
- RMS 계산 창 크기
- threshold

실측 데이터 기준으로 튜닝해야 합니다.

### 5. `device/esp32/firmware/src/calibration.cpp`

- rest baseline
- MVC peak
- 캘리브레이션 샘플 수

사용자별 편차 때문에 실제 측정 후 조정이 필요할 수 있습니다.

## 권장 bring-up 순서

1. ADC raw 값이 들어오는지 먼저 확인
2. band-pass 이후 값이 0이 아닌지 확인
3. `emg_ch1`만 우선 정상화
4. calibration 전/후 값 비교
5. JSONL 패킷으로 Pi에 전송

## 현재 패킷 반영 방식

이 센서는 초기 단계에서 단일 채널로 보고 있으므로:

- `emg_ch1` = 실제 EMG 처리값
- `emg_ch2` = `0`
- `emg_ch3` = `0`

이 방식은 허용되며, Pi 쪽도 이 전제를 받아들일 수 있게 맞추는 것이 안전합니다.

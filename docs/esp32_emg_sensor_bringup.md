# ESP32 EMG/IMU Sensor Bring-Up

이 문서는 `SZH-GJD001` 계열 단일 아날로그 EMG 센서와 `MPU-6050` IMU를 ESP32에 실제로 붙일 때, 값이 안 잡히는 문제를 줄이기 위한 점검 문서입니다.

## 전제

- 센서: `아두이노 근전도 EMG 모듈 KIT (건식 전극) [SZH-GJD001]`
- IMU: `MPU-6050` 계열 I2C IMU
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
- 현재 기본 구현은 `GPIO4`를 `ADC1_CH3`로 읽습니다.
- `read_imu_sample()`이 MPU-6050에서 accel/gyro raw 값을 읽어오도록 구현됨
- 실제 ADC 핀과 감쇠 설정 반영
- 실제 IMU 배선(`SDA`, `SCL`)과 주소(`0x68` 또는 `0x69`) 확인
- 센서 원시값이 어느 범위로 들어오는지 확인

현재는 EMG ADC 쪽은 placeholder이고, IMU 쪽은 I2C 읽기 경로가 구현돼 있습니다.

### 2. `device/esp32/firmware/main/main.cpp`

- 현재는 `AnalogEmgSensorSource`를 기본으로 연결합니다.
- 즉, IMU는 실제 값 우선, EMG는 ADC 미연동 시 0으로 유지하는 형태입니다.

### 3. `device/esp32/firmware/include/config.h`

- 샘플링 주기
- 한 프레임당 샘플 수
- ADC full scale
- EMG ADC GPIO
- 활성 threshold
- IMU I2C 포트
- IMU SDA/SCL 핀
- MPU-6050 주소

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

## MPU-6050 빠른 점검 포인트

현재 기본 설정:

- `I2C port`: `0`
- `SDA`: `GPIO8`
- `SCL`: `GPIO9`
- `address`: `0x68`
- `gyro bias calibration`: 부팅 직후 `100` 프레임(약 `2초`)

배선이 다르면 `device/esp32/firmware/include/config.h`에서 바꿔야 합니다.

JSON으로 확인할 때는 `JSON_V1`로 두고 아래처럼 보는 게 가장 빠릅니다.

```bash
cd ./device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyUSB0 -b 115200 flash monitor
```

정상이라면 아래 필드가 0이 아닌 실제 변화값으로 보입니다.

- `acc_x`
- `acc_y`
- `acc_z`
- `gyro_x`
- `gyro_y`
- `gyro_z`

초기화 로그 기준으로는 아래 두 줄이 먼저 보여야 정상입니다.

- `MPU-6050 WHO_AM_I = 0x68`
- `MPU-6050 ready on I2C port=...`

주의:

- 부팅 직후 약 `2초` 동안은 보드를 가만히 두는 것이 좋습니다.
- 이 구간에서 자이로 영점 오프셋을 평균내고, 이후 `gyro_*` 값에서 자동으로 빼 줍니다.
- 이 구간에 보드를 크게 움직이면 `gyro_*` 값이 계속 치우칠 수 있습니다.

반대로 아래 로그가 보이면 배선 또는 주소부터 다시 봐야 합니다.

- `failed to read MPU-6050 WHO_AM_I`
- `unexpected MPU-6050 WHO_AM_I value`
- `failed to wake MPU-6050`

## 권장 bring-up 순서

1. IMU I2C 배선과 주소가 맞는지 먼저 확인
2. 부팅 직후 `2초` 동안 보드를 가만히 둔 뒤 `JSON_V1`로 `acc_*`, `gyro_*` 값이 실제로 바뀌는지 확인
3. EMG 모듈 출력이 `GPIO4`에 연결된 상태에서 `emg_ch1` 값이 실제로 바뀌는지 확인
4. band-pass 이후 값이 0이 아닌지 확인
5. `emg_ch1`만 우선 정상화
6. calibration 전/후 값 비교
7. JSON 또는 binary 패킷으로 Pi에 전송

## 현재 패킷 반영 방식

이 센서는 초기 단계에서 단일 채널로 보고 있으므로:

- `emg_ch1` = 실제 EMG 처리값
- `emg_ch2` = `0`
- `emg_ch3` = `0`

이 방식은 허용되며, Pi 쪽도 이 전제를 받아들일 수 있게 맞추는 것이 안전합니다.

## EMG ADC 빠른 확인

현재 기본 설정:

- `EMG ADC GPIO`: `GPIO4`
- `ADC full scale`: `4095`
- `Serial plotter mode`: `device/esp32/firmware/include/config.h`의 `kEnableEmgRawSerialPlotterMode`
- `EMG bring-up packet mode`: `device/esp32/firmware/include/config.h`의 `kEnableEmgBringupPacketMode`
- `Serial plotter interval`: `50ms`
- `Serial plotter window`: 최근 `20`개 샘플 기준 `min/max`

실행:

```bash
cd ./device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyUSB0 -b 115200 flash monitor
```

정상이라면:

- 현재 기본 설정은 `kEnableEmgBringupPacketMode = false`라서 `emg_ch1`는 normalized 값입니다.
- 실센서 입력이 실제로 들어오는지 확인해야 할 때만 `kEnableEmgBringupPacketMode = true`로 바꿔 EMG RMS/envelope를 직접 봅니다.
- 가만히 있을 때 `emg_ch1`는 작은 값에 머뭅니다.
- 근육에 힘을 주면 `emg_ch1`가 평소보다 커집니다.
- 현재 구조는 단일 채널이므로 `emg_ch2`, `emg_ch3`는 `0`이 정상입니다.

반대로 계속 `0.0000`이면 먼저 아래를 봐야 합니다.

- EMG 모듈 출력 핀이 정말 `GPIO4`에 연결됐는지
- `VCC`, `GND`가 정상인지
- `GPIO4`가 다른 기능에 점유되지 않았는지
- `device/esp32/firmware/include/config.h`의 `kAnalogEmgAdcGpio` 값이 실제 배선과 맞는지

## EMG raw Serial Plotter 모드

`emg_ch1`가 계속 `0.0000`이면 먼저 필터 전 raw ADC 값이 들어오는지 봐야 합니다.

1. `device/esp32/firmware/include/config.h`에서 아래 값을 켭니다.

```cpp
inline constexpr bool kEnableEmgRawSerialPlotterMode = true;
```

2. 다시 빌드/플래시합니다.

```bash
cd ./device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyUSB0 -b 115200 flash monitor
```

이 모드에서는 JSON 대신 아래 3개 값이 함께 출력됩니다.

- `raw`: 현재 ADC 샘플
- `min`: 최근 `20`개 샘플 최소값
- `max`: 최근 `20`개 샘플 최대값

- 가만히 있을 때도 `raw` 값이 조금 흔들리면 ADC 입력은 살아 있는 상태입니다.
- 근육에 힘을 줄 때 `raw`와 `max-min` 폭이 커지면 EMG 모듈 출력이 실제로 들어오고 있는 것입니다.

Serial Plotter 확인이 끝나면 다시:

```cpp
inline constexpr bool kEnableEmgRawSerialPlotterMode = false;
```

로 돌려야 JSON/BINARY 패킷 송신 경로가 다시 동작합니다.

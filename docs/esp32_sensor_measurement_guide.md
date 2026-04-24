# ESP32 센서 측정/비교 가이드

이 문서는 EMG/IMU bring-up 과정에서 **어떤 값을 저장하고**, **어떤 기준으로 비교해야 하는지**를 정리한 문서입니다.  
목표는 나중에 보고서에 그대로 쓸 수 있는 **측정 조건 + 수치 요약 기준**을 남기는 것입니다.

## 기본 원칙

- 비교는 항상 같은 조건에서 합니다.
- 원인 분리를 위해 `IMU`와 `EMG`를 한 번에 보지 않습니다.
- 실센서 bring-up 중 수치 비교는 먼저 `JSON_V1`로 합니다.
- `BINARY_V2`는 같은 처리 결과를 다른 wire format으로 보내는 것이므로, 값 검증이 끝난 뒤 전송 검증에 씁니다.

## 현재 기록해야 하는 핵심 설정값

`device/esp32/firmware/include/config.h` 기준:

- `kSampleIntervalMs = 20`
- `kImuGyroBiasCalibrationSamples = 100`
- `kImuSmoothingAlpha = 0.20`
- `kMotionDetectionThreshold = 0.50`
- `kAnalogEmgSamplesPerFrame = 10`
- `kAnalogEmgAdcFullScale = 4095.0`
- `kAnalogEmgAdcGpio = 4`
- `kImuI2cSdaGpio = 8`
- `kImuI2cSclGpio = 9`
- `kMpu6050Address = 0x68`

보고서에는 위 값들을 **측정 당시 설정값**으로 함께 적어야 합니다.

## 권장 측정 시나리오

### 1. IMU 정지 상태

목적:

- 자이로 bias 보정이 잘 되는지 확인
- 정지 상태에서 `flags`가 과민하게 켜지는지 확인

조건:

- 부팅 직후 약 `2초` 동안 보드를 가만히 둠
- 이후 보드를 책상 위에 고정한 상태로 `10초` 정도 측정

기록할 것:

- `acc_x`, `acc_y`, `acc_z`
- `gyro_x`, `gyro_y`, `gyro_z`
- `flags`

판단 기준:

- `gyro_*` 평균이 `0` 근처인지
- `gyro_*` 표준편차가 작은지
- `flags`가 대부분 `2`인지

### 2. IMU 동작 상태

목적:

- 기울임/회전에 따라 accel, gyro가 충분히 반응하는지 확인

조건:

- X/Y/Z축 방향으로 천천히 기울이기
- 손으로 회전시키기

기록할 것:

- `acc_x`, `acc_y`, `acc_z`
- `gyro_x`, `gyro_y`, `gyro_z`
- `flags`

판단 기준:

- 기울일 때 `acc_*`가 축 방향에 맞게 변하는지
- 돌릴 때 `gyro_*`가 커지는지
- 움직임 구간에서 `flags = 6`이 나오는지

### 3. EMG 휴식 상태

목적:

- 전극 접촉과 ADC 입력이 살아 있는지 확인
- 휴식 상태 노이즈 크기를 정량화

조건:

- EMG 모듈 출력은 `GPIO4`
- 전극 부착 후 힘을 주지 않고 `10초` 측정

기록할 것:

- `emg_ch1`

판단 기준:

- 계속 `0.0000`이면 배선/전원/전극 문제 의심
- 값이 작게 흔들리면 입력은 살아 있는 상태

### 4. EMG 수축 상태

목적:

- 실제 근육 수축 시 `emg_ch1`가 휴식 대비 충분히 커지는지 확인

조건:

- 같은 자세에서 `휴식 5초 -> 수축 5초 -> 휴식 5초`

기록할 것:

- `emg_ch1`

판단 기준:

- 수축 구간 평균이 휴식 구간 평균보다 유의하게 큰지
- 휴식/수축 구간이 분리되는지

## JSON 로그 저장 방법

실기기 수치 비교는 `JSON_V1`에서 먼저 수행합니다.

```bash
cd ./device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyUSB0 -b 115200 flash monitor | tee /tmp/esp32_sensor_run_01.log
```

포트가 `ttyACM0`이면 그 값으로 바꿉니다.

## 로그 통계 요약 방법

저장한 JSON 로그는 아래 스크립트로 바로 요약할 수 있습니다.

```bash
python3 ./device/esp32/scripts/summarize_json_sensor_log.py /tmp/esp32_sensor_run_01.log
```

출력 항목:

- `packets`
- `duration_ms`
- `first_seq`, `last_seq`
- 각 필드별
  - `min`
  - `max`
  - `avg`
  - `stddev`
  - `range`

## 보고서에 바로 남길 표 예시

### IMU 정지 상태

| 항목 | avg | stddev | min | max |
| --- | --- | --- | --- | --- |
| gyro_x |  |  |  |  |
| gyro_y |  |  |  |  |
| gyro_z |  |  |  |  |
| acc_x |  |  |  |  |
| acc_y |  |  |  |  |
| acc_z |  |  |  |  |

### EMG 휴식/수축 비교

| 항목 | 휴식 avg | 수축 avg | 휴식 stddev | 수축 stddev |
| --- | --- | --- | --- | --- |
| emg_ch1 |  |  |  |  |

## 해석 주의

- `JSON_V1`와 `BINARY_V2`는 **처리 결과는 같고 출력 포맷만 다릅니다.**
- 따라서 센서 품질 비교는 먼저 `JSON_V1`에서 끝내고, 이후 `BINARY_V2`는 전송 확인에 씁니다.
- Pi에서 값이 튄다면, 먼저 ESP32 JSON 로그가 안정적인지 확인한 뒤 Pi unpack 문제를 의심해야 합니다.

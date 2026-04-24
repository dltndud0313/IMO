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

## 바이너리 검증 방법

JSON 기준 수치 검증이 끝난 뒤에는 같은 처리 결과가 `BINARY_V2`에도 그대로 실리는지 확인합니다.

```bash
cd ./device/esp32/firmware
python3 ../scripts/decode_binary_sensor_stream.py --port /dev/ttyUSB0
```

확인 기준:

- 이완 상태에서는 `emg_ch1`가 작아야 함
- 수축 상태에서는 `emg_ch1`가 커져야 함
- 자세 변화 시 `acc_*`, `gyro_*`가 같이 반응해야 함

주의:

- binary는 `float`를 그대로 보내지 않고 `1000` 배 스케일한 `int16_t`를 보냅니다.
- 예를 들어 JSON에서 `0.0002`였던 값은 binary에서 `0`으로 보일 수 있습니다.
- 따라서 매우 작은 휴식 구간은 JSON보다 binary에서 더 계단형으로 보이는 것이 정상입니다.

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

## 1차 실측 기록

측정 일시:

- `2026-04-24`

측정 조건:

- `JSON_V1`
- `kEnableEmgBringupPacketMode = true`
- `emg_ch1`는 정규화값이 아니라 EMG RMS/envelope
- EMG 입력 GPIO: `GPIO4`
- IMU: `MPU-6050`

로그 파일:

- 휴식: `/tmp/emg_rest.log`
- 수축: `/tmp/emg_contract.log`

요약 결과:

### EMG 휴식/수축 1차 비교

| 항목 | 휴식 avg | 수축 avg | 휴식 stddev | 수축 stddev | 휴식 max | 수축 max |
| --- | --- | --- | --- | --- | --- | --- |
| emg_ch1 | 0.0207 | 0.0345 | 0.0189 | 0.0198 | 0.0767 | 0.0822 |

해석:

- 수축 평균은 휴식 평균 대비 약 `1.67배` 증가함
- 즉, EMG 센서 입력은 실제로 들어오고 있으며 힘을 줄 때 반응함
- 다만 `max` 차이는 크지 않아 반응 폭은 아직 제한적임
- 수축 로그에서 IMU 흔들림이 함께 커져, 팔/보드 움직임이 섞였을 가능성이 큼

## 2차 실측 기록

측정 일시:

- `2026-04-24`

측정 조건:

- `JSON_V1`
- `kEnableEmgBringupPacketMode = true`
- `emg_ch1`는 정규화값이 아니라 EMG RMS/envelope
- 팔/보드 움직임을 줄이고 휴식/수축을 다시 분리 측정

로그 파일:

- 휴식: `/tmp/emg_rest.log`
- 수축: `/tmp/emg_contract.log`

요약 결과:

### EMG 휴식/수축 2차 비교

| 항목 | 휴식 avg | 수축 avg | 휴식 stddev | 수축 stddev | 휴식 max | 수축 max |
| --- | --- | --- | --- | --- | --- | --- |
| emg_ch1 | 0.0004 | 0.0082 | 0.0005 | 0.0038 | 0.0040 | 0.0189 |

해석:

- 수축 평균은 휴식 평균 대비 약 `20.5배` 증가함
- `max`도 `0.0040 -> 0.0189`로 증가해 휴식/수축 구분이 1차보다 선명함
- 이번 로그는 IMU 흔들림도 크지 않아, EMG 반응 확인용 성공 데이터로 사용 가능함

정리:

- 1차 측정: 수축 반응 확인은 됐지만 IMU 움직임이 섞여 해석이 약했음
- 2차 측정: 휴식/수축 구분이 선명하게 확인되어 보고서 기준 데이터로 채택 가능

### 1차 IMU 안정 구간 요약

| 항목 | avg | stddev | range |
| --- | --- | --- | --- |
| acc_x | -0.6444 | 0.0014 | 0.0084 |
| acc_y | -0.7342 | 0.0011 | 0.0073 |
| acc_z | 0.1099 | 0.0015 | 0.0074 |
| gyro_x | -0.0059 | 0.0393 | 0.3340 |
| gyro_y | 0.0214 | 0.0964 | 0.5383 |
| gyro_z | -0.0122 | 0.1359 | 0.8860 |

해석:

- 휴식 로그 기준 IMU는 정지 상태에서 비교적 안정적임
- 따라서 현재 재측정 우선순위는 IMU가 아니라 EMG 반응폭 개선과 측정 조건 통제임

## 다시 테스트할 항목

### 1. EMG 휴식/수축 재측정

목적:

- 휴식과 수축 구간 차이를 더 명확하게 벌리기

조건:

- 팔과 보드를 최대한 고정
- 같은 근육 위치에서 전극 재부착
- `휴식 5초 -> 수축 5초 -> 휴식 5초`

확인할 것:

- `emg_ch1 avg`
- `emg_ch1 max`
- `emg_ch1 range`

성공 기준:

- 수축 평균이 휴식 평균보다 확실히 큼
- `max`와 `range`도 함께 증가

### 2. 전극 위치/접촉 재조정

목적:

- 현재 반응폭이 작은 원인이 전극 위치나 접촉 상태인지 확인

조건:

- 전극 위치를 약간씩 바꿔가며 같은 테스트 반복
- 건식 전극 접촉 상태 점검

확인할 것:

- 같은 자세/같은 수축 조건에서 `emg_ch1 avg` 증가 여부

### 3. EMG 모듈 게인 확인

목적:

- 모듈 출력 폭을 조금 더 확보할 수 있는지 확인

조건:

- 가변저항이 있다면 아주 조금씩만 조정
- 조정 전후 같은 휴식/수축 로그 비교

주의:

- 게인을 한 번에 크게 바꾸지 말 것
- 포화되면 오히려 해석이 어려워짐

### 4. normalized 경로 재검증

목적:

- 실센서 입력 확인이 끝난 뒤 최종 사용자 값 경로를 검증

조건:

- `device/esp32/firmware/include/config.h`에서 `kEnableEmgBringupPacketMode = false`
- 다시 휴식/수축 로그 측정

확인할 것:

- normalized `emg_ch1`가 휴식/수축을 구분하는지

## 해석 주의

- `JSON_V1`와 `BINARY_V2`는 **처리 결과는 같고 출력 포맷만 다릅니다.**
- 따라서 센서 품질 비교는 먼저 `JSON_V1`에서 끝내고, 이후 `BINARY_V2`는 전송 확인에 씁니다.
- Pi에서 값이 튄다면, 먼저 ESP32 JSON 로그가 안정적인지 확인한 뒤 Pi unpack 문제를 의심해야 합니다.

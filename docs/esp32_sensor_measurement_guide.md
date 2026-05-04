# ESP32 센서 측정 가이드 (Current)

이 문서는 **캘리브레이션 없는 ESP32 수집기** 기준 측정 절차입니다.
캘리브레이션은 Pi/앱에서 수행합니다.

## 현재 전제

- EMG: 4채널 (`GPIO 4/5/6/7`)
- IMU: 3개
  - IMU1: `0x68`, `SDA=8`, `SCL=9`
  - IMU2: `0x69`, `SDA=8`, `SCL=9`
  - IMU3: `0x68`, `SDA=10`, `SCL=11`
- 패킷: `BINARY_V2` 64바이트 고정
- 샘플 주기: 20ms (50Hz)

## 1. 펌웨어 올리기

```bash
cd ./device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyUSB0 -b 115200 flash
```

## 2. 실시간 수신 확인

```bash
python3 ../scripts/decode_binary_sensor_stream.py --port /dev/ttyUSB0
```

확인 포인트:

- `emg=(ch1,ch2,ch3,ch4)` 값이 채널별로 변하는지
- `imu1/imu2/imu3` 가속도/자이로가 자세 변화에 반응하는지
- `flags`에서 bias 준비/모션 비트가 기대대로 바뀌는지

## 3. IMU 점검 시나리오

1. 부팅 후 2초 정지
2. X/Y/Z 축으로 천천히 기울이기
3. 손목/팔 회전

정상 기준:

- 정지 구간에서 gyro 평균이 0 근처
- 움직임 구간에서 gyro/accel이 축 방향으로 증가

## 4. EMG 점검 시나리오

1. 이완 5초
2. 수축 5초
3. 이완 5초

정상 기준:

- 이완에서 EMG가 낮고
- 수축에서 EMG가 명확히 상승
- 4채널 중 연결 채널에 우선 반응

## 5. Pi팀 공유 필수 항목

프로토콜 변경 시 아래를 같이 전달해야 합니다.

1. 프레임 길이 (`64 bytes`)
2. 상태 코드 정의
3. 스케일 (`emg/accel:1000`, `gyro:100`)
4. flags 비트 의미

참고:

- `shared/protocol/esp32_pi_packet_format.md`

## 6. EMG 튜닝 이력 정리

이 프로젝트의 EMG 튜닝 목표는 "의료용 절대 측정"이 아니라 "운동보조용 실시간 게이지"에 가깝다.

최종 의도:

- 부착 후 휴식 상태는 `0.000`
- 힘을 주면 값 상승
- 힘 유지 중에는 값이 급락하지 않음
- 힘을 빼면 자연스럽게 감소
- 센서 탈착 시 `1.000` 경고
- 일반 힘 게이지는 `0.900` 상한

### 초기 방식 vs 현재 방식

| 항목 | 초기 적용/실험 방식 | 현재 방식 |
| --- | --- | --- |
| 상태머신 | ESP32 내부 캘리브레이션 단계 존재 | 캘리브레이션 제거, 즉시 `STREAMING` |
| EMG 해석 | band-pass, 정규화, MVC 성격 실험 | 부착 직후 baseline 대비 raw 변화량 envelope |
| 표시 목표 | 신호가 보이는지 우선 확인 | 운동보조용 게이지처럼 보이게 튜닝 |
| 탈착 처리 | 실험 단계별 편차 큼 | 탈착 경고 `1.000` 고정 |
| 일반 게이지 상한 | `1.000`까지 사용 | 일반 EMG는 `0.900`, 탈착만 `1.000` |
| 실행 | 긴 수신 명령 직접 입력 | `./stream` 래퍼 사용 가능 |

### 현재 핵심 수치

파일 기준: `device/esp32/firmware/include/config.h`

| 항목 | 값 | 의미 |
| --- | --- | --- |
| `kSampleIntervalMs` | `20` | 송신 주기 20ms, 50Hz |
| `kEmgMovingAverageWindow` | `16` | 표시 안정화를 위한 평균 창 |
| `kEmgRmsWindow` | `16` | RMS 계산 창 |
| `kEmgHistoryWindow` | `40` | 표시 히스토리 길이 |
| `kEmgDisplayAttackAlpha` | `0.12` | 상승 반응 속도 |
| `kEmgDisplayReleaseAlpha` | `0.92` | 하강 반응 속도 |
| `kEmgDisplayZeroReleaseAlpha` | `0.055` | 0 복귀 구간 하강 속도 |
| `kEmgDisplayHoldFrames` | `16` | 유지 중 급락 완화 프레임 수 |
| `kEmgRestDisplayThreshold` | `0.010` | 휴식으로 보고 0에 붙이는 기준 |
| `kActivationThresholdOn` | `0.011` | 힘 신호로 보는 on 기준 |
| `kEmgDisplayGain` | `20.00` | 게이지 증폭 계수 |
| `kEmgDisplaySignalMax` | `0.900` | 일반 근육 게이지 최대치 |
| `kEmgDisplayMax` | `1.000` | 탈착 포함 전체 표시 최대치 |
| `kAnalogEmgRestBaselineSamples` | `100` | baseline 수집 raw 샘플 수 |
| `kAnalogEmgFrameNoiseFloor` | `0.001` | 프레임 노이즈 하한 |
| `kAnalogEmgRestNoiseFloorMultiplier` | `2.5` | 휴식 노이즈 기반 추가 noise floor 배수 |
| `kAnalogEmgBaselineMaxNoise` | `0.040` | baseline 재측정 기준 |
| `kAnalogEmgMinSignalSamples` | `2` | 프레임 유효 신호 최소 샘플 수 |
| `kAnalogEmgDetachedMagnitudeThreshold` | `0.42` | 탈착 후보로 보는 크기 |
| `kAnalogEmgReattachMagnitudeThreshold` | `0.08` | 재부착 안정 범위 |
| `kAnalogEmgReattachConsecutiveFrames` | `5` | 재부착 인정 연속 프레임 수 |

### 포트폴리오용 요약 문장 예시

- ESP32 펌웨어에서 EMG/IMU 수집 파이프라인을 재설계하고, 캘리브레이션 없는 즉시 스트리밍 구조로 단순화했다.
- EMG는 baseline 대비 envelope 기반으로 재해석하고, 운동보조용 게이지에 맞춰 휴식 `0.000`, 탈착 `1.000`, 일반 수축 상한 `0.900`으로 튜닝했다.
- USB Serial 기준 `BINARY_V2` 64바이트 고정 프레임을 정의하고, Pi 수신 디코더와 테스트 스크립트를 함께 정리했다.

## 7. 트러블슈팅 기록

### 7-1. IMU2가 보드에 연결되어 있는데도 0으로만 보임

- 증상:
  - `imu2_acc`, `imu2_gyro`가 계속 `0.000`
- 확인:
  - I2C scan에서는 `0x68`, `0x69` 둘 다 검출
  - 추가로 `WHO_AM_I`, wake, sample read를 직접 확인
- 원인:
  - 단순 probe 성공과 실제 스트리밍 준비 완료는 다름
  - 준비 상태 비트와 채널별 read 경로를 분리 확인해야 했음
  - 이후 IMU3는 `10/11` 별도 I2C 버스로 분리해 단일 버스 가정을 제거
- 대응:
  - `WHO_AM_I` 확인 로직 추가
  - IMU1/2는 `8/9`, IMU3는 `10/11` 버스로 분리
  - 최종적으로 주소는 `{0x68,0x69,0x68}` 구성

### 7-2. 바이너리 디코더가 중간에 끊기거나 이상한 문자 출력

- 증상:
  - `decode_binary_sensor_stream.py` 실행 시 깨진 문자 출력
  - 로그가 멈추거나 프레임 decode 실패 반복
- 원인:
  - 텍스트 로그와 바이너리 프레임이 같은 serial에 섞임
  - `idf.py monitor`와 decoder 동시 사용
- 대응:
  - `kEnableImuInitTextLog = false`
  - monitor 종료 후 decoder만 단독 실행

### 7-3. EMG가 탈착 후 재부착해도 기준값이 이상하게 남음

- 증상:
  - 다시 붙였는데 `0.000`으로 바로 안 돌아감
  - 특정 값에서 시작해 그 주변만 증감
- 원인:
  - 재부착 후에도 이전 baseline이 영향
  - 탈착 판정과 재부착 인정 기준이 접촉 조건 변화에 민감
- 대응:
  - baseline reset, reattach frame 수, magnitude threshold를 여러 차례 실험
  - 현재는 최종 커밋 기준 안정값으로 되돌려 보존

### 7-4. 힘 유지 중 EMG 값이 많이 흔들림

- 증상:
  - 최대/최소 편차가 큼
  - 힘을 유지해도 값이 급락
- 원인:
  - raw EMG 자체가 간헐적으로 떨어짐
  - 표시값 smoothing이 약하면 dip가 그대로 게이지에 반영
- 대응:
  - moving average / RMS / hold / release alpha를 반복 튜닝
  - 현재는 "운동보조 게이지처럼 보이는지"를 우선 기준으로 유지

### 7-5. 손으로 눌러야 EMG가 잘 인식됨

- 증상:
  - 그냥 붙이면 반응이 약함
  - 눌러주면 신호가 살아남
- 원인:
  - 코드 문제만이 아니라 전극 접촉 저항, 부착 위치, 피부 상태 영향이 큼
- 대응:
  - 전극 접촉/위치 안정화 우선
  - baseline은 힘을 뺀 상태에서 시작
  - 코드 튜닝은 그 다음 단계

# ESP32-Pi 패킷 포맷

ESP32는 센서 처리 결과를 USB Serial 기준 `JSON Lines(JSONL)` 한 줄로 Raspberry Pi에 전달합니다.

## 전송 원칙

- 한 패킷은 한 줄 JSON 문자열입니다.
- 줄바꿈(`\n`) 기준으로 패킷 경계를 구분합니다.
- 초기 MVP에서는 디버깅이 쉬운 텍스트 포맷을 유지합니다.
- 스키마 버전은 `emg-glass.v1` 입니다.

## 필수 필드

| 필드 | 설명 |
| --- | --- |
| `schema` | 패킷 스키마 버전 문자열 |
| `seq` | 송신 순번 |
| `timestamp_ms` | ESP32 기준 밀리초 타임스탬프 |
| `emg_ch1` | 정규화된 EMG 채널 1 활성도 |
| `emg_ch2` | 정규화된 EMG 채널 2 활성도 |
| `emg_ch3` | 정규화된 EMG 채널 3 활성도 |
| `acc_x` | 가속도 X축 값 |
| `acc_y` | 가속도 Y축 값 |
| `acc_z` | 가속도 Z축 값 |
| `gyro_x` | 자이로 X축 값 |
| `gyro_y` | 자이로 Y축 값 |
| `gyro_z` | 자이로 Z축 값 |
| `state` | 현재 상태머신 상태 문자열 |
| `flags` | mock/calibration/motion 상태 비트 필드 |

## 선택 필드

| 필드 | 설명 |
| --- | --- |
| `rep_index` | 반복 횟수 추적이 필요할 때 사용하는 선택 필드 |

## 단일채널 EMG 센서 사용 시 주의

- 현재 검토 중인 `SZH-GJD001` 계열 센서는 단일 아날로그 EMG 채널 전제를 우선 사용합니다.
- 이 경우 초기 하드웨어 연동 단계에서는
  - `emg_ch1` 에 실제 EMG 처리값을 넣고
  - `emg_ch2`, `emg_ch3` 는 `0` 으로 유지할 수 있습니다.
- Raspberry Pi 수신기는 위 상황도 정상 패킷으로 받아들이도록 구현하는 것이 안전합니다.

## 예시

```json
{"schema":"emg-glass.v1","seq":12,"timestamp_ms":240,"emg_ch1":0.5342,"emg_ch2":0.4210,"emg_ch3":0.2871,"acc_x":0.0120,"acc_y":0.1410,"acc_z":1.0084,"gyro_x":0.0221,"gyro_y":0.0310,"gyro_z":0.1180,"state":"STREAMING","flags":7}
```

## 라즈베리파이 수신 기준

Raspberry Pi 수신기는 아래 규칙을 기준으로 ESP32 패킷을 읽습니다.

- 입력 경로: USB Serial 한 줄 입력
- 경계 구분: 줄바꿈(`\n`) 기준
- 예상 스키마: `emg-glass.v1`
- 필수 검증 항목:
  - `schema`
  - `seq`
  - `timestamp_ms`
  - `emg_ch1`
  - `emg_ch2`
  - `emg_ch3`
  - `acc_x`
  - `acc_y`
  - `acc_z`
  - `gyro_x`
  - `gyro_y`
  - `gyro_z`
  - `state`
  - `flags`
- 선택 항목:
  - `rep_index`

Pi 쪽에서는 위 필드 이름을 그대로 사용해 파싱하는 것을 전제로 합니다.  
따라서 필드 이름 변경, 삭제, 타입 변경이 필요하면 ESP32와 Pi 코드를 함께 수정해야 합니다.

## 라즈베리파이 수신 시 예외 처리 원칙

- 빈 줄은 무시
- JSON 형식이 아니면 폐기
- 필수 필드가 없으면 폐기
- `schema` 값이 다르면 경고 후 폐기
- 손상된 패킷이 들어와도 전체 수신 루프는 멈추지 않고 다음 줄 계속 처리

## 코드 위치

- 송신 타입 정의: `device/esp32/firmware/include/types.h`
- JSONL 인코딩/디코딩: `device/esp32/firmware/src/packet.cpp`
- Serial 송신: `device/esp32/firmware/src/transport_serial.cpp`

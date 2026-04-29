# ESP32 센서 측정 가이드 (Current)

이 문서는 **캘리브레이션 없는 ESP32 수집기** 기준 측정 절차입니다.
캘리브레이션은 Pi/앱에서 수행합니다.

## 현재 전제

- EMG: 4채널 (`GPIO 4/5/6/7`)
- IMU: 3개 (`0x68/0x69/0x6A`)
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

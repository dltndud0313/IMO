# ESP32 Firmware (ESP-IDF)

현재 펌웨어는 **저지연 데이터 수집 장치** 역할에 집중합니다.

- ESP32 내부 캘리브레이션 없음
- 전원 인가 후 즉시 `STREAMING`
- EMG 4채널 + IMU 3개 수집
- 기본 전송: `BINARY_V2` 64바이트 고정 프레임

## 실행

```bash
cd ./device/esp32/firmware
source ~/esp/esp-idf/export.sh
idf.py build
idf.py -p /dev/ttyUSB0 -b 115200 flash monitor
```

## 호스트 테스트

```bash
./device/esp32/scripts/run_firmware_host_tests.sh
```

## 현재 설정 핵심값

`include/config.h` 기준:

- `kDefaultPacketFormat = BINARY_V2`
- `kSampleIntervalMs = 20` (50Hz)
- `kAnalogEmgAdcGpios = {4,5,6,7}`
- `kMpu6050Addresses = {0x68,0x69,0x6A}`
- `kImuI2cSdaGpio = 8`, `kImuI2cSclGpio = 9`
- `kImuGyroBiasCalibrationSamples = 100`
- `kImuGyroDeadzoneDps = 0.80`
- `kImuAccelDeadzoneG = 0.015`
- `kMotionDetectionThreshold = 1.50`

## 모듈 역할

- `src/sensor_analog_emg.cpp`
  - EMG 4채널 ADC + MPU-6050 3개 I2C 수집
- `src/emg_filter.cpp`
  - 채널별 RMS + 표시용 smoothing + hysteresis active
- `src/imu_processor.cpp`
  - gyro bias + deadzone + EMA + motion delta
- `src/runtime_pipeline.cpp`
  - 센서 프레임 처리 후 패킷 생성/송신
- `src/packet.cpp`
  - JSON/BINARY 인코딩/디코딩

## Pi 연동

64바이트 프레임 디코드:

```bash
python3 ./device/esp32/scripts/decode_binary_sensor_stream.py --port /dev/ttyUSB0
```

프로토콜 상세:

- `shared/protocol/esp32_pi_packet_format.md`

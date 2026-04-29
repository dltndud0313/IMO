// 패킷 스키마, 샘플링 주기, 경량 처리 기본값을 한곳에 모은 설정 파일.
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

#include "types.h"

namespace mvp {

inline constexpr char kPacketSchemaJsonV1[] = "emg-glass.v1";
inline constexpr char kPacketSchemaBinaryV2[] = "emg-glass.v2";
inline constexpr uint8_t kPacketProtocolVersionBinaryV2 = 2;
inline constexpr PacketFormat kDefaultPacketFormat = PacketFormat::BINARY_V2;
inline constexpr uint32_t kSerialBaudRate = 115200;
inline constexpr uint32_t kSampleIntervalMs = 20;
inline constexpr std::size_t kEmgMovingAverageWindow = 16;
inline constexpr std::size_t kEmgRmsWindow = 16;
inline constexpr std::size_t kEmgHistoryWindow = 40;
inline constexpr float kEmgDisplayAttackAlpha = 0.12F;
inline constexpr float kEmgDisplayReleaseAlpha = 0.99F;
inline constexpr float kEmgDisplayZeroReleaseAlpha = 0.040F;
inline constexpr std::size_t kEmgDisplayHoldFrames = 18;
inline constexpr float kEmgDisplayNoiseFloor = 0.000F;
// 최종 표시값이 이 값 이하면 휴식으로 보고 0.000으로 붙인다.
inline constexpr float kEmgRestDisplayThreshold = 0.010F;
inline constexpr float kEmgDisplayZeroClamp = kEmgRestDisplayThreshold;
// 운동보조 표시값은 휴식 기준선 대비 변화량을 보기 쉽게 키운다.
inline constexpr float kEmgDisplayGain = 20.00F;
inline constexpr float kEmgDisplaySignalMax = 0.900F;
inline constexpr float kEmgDisplayMax = 1.000F;
// 센서 소스가 탈착을 감지하면 이 값으로 표시 경고를 보낸다. 근육 히스토리에는 넣지 않는다.
inline constexpr float kEmgDetachInputThreshold = 0.99F;
inline constexpr float kActivationThresholdOn = 0.011F;
inline constexpr float kActivationThresholdOff = kEmgRestDisplayThreshold;
inline constexpr std::size_t kImuGyroBiasCalibrationSamples = 100;
inline constexpr float kImuSmoothingAlpha = 0.20F;
inline constexpr float kImuGyroDeadzoneDps = 0.80F;
inline constexpr float kImuAccelDeadzoneG = 0.015F;
inline constexpr float kMotionDetectionThreshold = 1.50F;

// EMG 입력은 "운동보조용 아날로그 활성도"로 취급한다.
// 부팅 직후 힘을 뺀 상태를 휴식 기준으로 잡고, 이후 기준선 대비 raw 변화량만 사용한다.
inline constexpr uint32_t kAnalogEmgRecommendedSampleRateHz = 500;
inline constexpr std::size_t kAnalogEmgSamplesPerFrame = 10;
inline constexpr float kAnalogEmgAdcFullScale = 4095.0F;
inline constexpr std::size_t kAnalogEmgRestBaselineSamples = 100;
inline constexpr float kAnalogEmgFrameNoiseFloor = 0.001F;
inline constexpr float kAnalogEmgRestNoiseFloorMultiplier = 1.0F;
inline constexpr float kAnalogEmgDetachRawLowRatio = 0.02F;
inline constexpr float kAnalogEmgDetachRawHighRatio = 0.98F;
inline constexpr float kAnalogEmgDetachedMagnitudeThreshold = 0.42F;
inline constexpr float kAnalogEmgReattachMagnitudeThreshold = 0.08F;
inline constexpr std::size_t kAnalogEmgDetachConsecutiveFrames = 3;
inline constexpr std::size_t kAnalogEmgReattachConsecutiveFrames = 5;
inline constexpr float kAnalogEmgDetachFrameValue = 1.000F;
inline constexpr std::array<int, kEmgChannelCount> kAnalogEmgAdcGpios = {4, 5, 6, 7};
// 현재 하드웨어(EMG 1개)에서는 GPIO4만 활성화하고 나머지 채널은 소프트웨어로 비활성화한다.
inline constexpr std::array<bool, kEmgChannelCount> kAnalogEmgChannelEnabled = {true, false, false, false};
inline constexpr bool kEnableEmgRawSerialPlotterMode = false;
inline constexpr std::size_t kEmgRawSerialPlotterWindowSamples = 20;
inline constexpr uint32_t kEmgRawSerialPlotterIntervalMs = 50;
// BINARY_V2 수신 중에는 텍스트 로그가 바이너리 프레임을 깨뜨릴 수 있으므로 기본 비활성화한다.
inline constexpr bool kEnableImuInitTextLog = false;

// MPU-6050 기본 I2C 설정값. 보드 배선에 따라 SDA/SCL은 실제 연결값으로 바꿔야 한다.
inline constexpr int kImuI2cPort = 0;
inline constexpr int kImuI2cSdaGpio = 8;
inline constexpr int kImuI2cSclGpio = 9;
inline constexpr uint32_t kImuI2cClockHz = 100000;
inline constexpr int kImuI2cTransactionTimeoutMs = 20;
// MPU-6050 단독 주소는 일반적으로 0x68/0x69 두 개만 사용 가능하다.
// 세 번째 슬롯(0x6A)은 다른 IMU를 붙이거나, 멀티플렉서 적용 시에만 유효하다.
inline constexpr std::array<uint8_t, kImuSensorCount> kMpu6050Addresses = {0x68, 0x69, 0x6A};
// 현재 장착된 IMU만 읽는다. 미장착 슬롯을 계속 probe하면 스트리밍 주기가 밀릴 수 있다.
inline constexpr std::array<bool, kImuSensorCount> kImuSensorEnabled = {true, true, false};

inline constexpr uint32_t kFlagMockData = 1U << 0;
inline constexpr uint32_t kFlagImuBiasReady = 1U << 1;
inline constexpr uint32_t kFlagMotionDetected = 1U << 2;
inline constexpr uint32_t kFlagImuPartialReady = 1U << 3;

}  // namespace mvp

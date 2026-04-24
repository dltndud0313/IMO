// 패킷 스키마, 샘플링 주기, 경량 처리 기본값을 한곳에 모은 설정 파일.
#pragma once

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
inline constexpr std::size_t kEmgMovingAverageWindow = 5;
inline constexpr std::size_t kEmgRmsWindow = 8;
inline constexpr std::size_t kEmgHistoryWindow = 16;
inline constexpr std::size_t kCalibrationSampleCount = 32;
inline constexpr std::size_t kMvcReferenceTopSampleCount = 8;
inline constexpr float kMvcReferenceMinimumMargin = 0.05F;
inline constexpr float kEmgAttackAlpha = 0.35F;
inline constexpr float kEmgReleaseAlpha = 0.08F;
inline constexpr float kActivationThresholdOn = 0.20F;
inline constexpr float kActivationThresholdOff = 0.12F;
inline constexpr std::size_t kImuGyroBiasCalibrationSamples = 100;
inline constexpr float kImuSmoothingAlpha = 0.20F;
inline constexpr float kMotionDetectionThreshold = 0.50F;

// SZH-GJD001 계열 단일 아날로그 EMG 센서를 붙일 때 참고할 기본값.
// 현재 패킷 송신 주기는 50Hz(20ms)라서, 센서는 더 빠르게 읽고 한 프레임에 묶어 보내는 쪽이 안전하다.
inline constexpr uint32_t kAnalogEmgRecommendedSampleRateHz = 500;
inline constexpr std::size_t kAnalogEmgSamplesPerFrame = 10;
inline constexpr float kAnalogEmgAdcFullScale = 4095.0F;
inline constexpr int kAnalogEmgAdcGpio = 4;
inline constexpr bool kEnableEmgRawSerialPlotterMode = false;
// bring-up 동안에는 정규화 전 RMS/envelope를 패킷에 그대로 실어 실제 센서 입력이 보이는지 먼저 확인한다.
// 검증이 끝나면 false로 돌려 최종 normalized 경로를 사용한다.
inline constexpr bool kEnableEmgBringupPacketMode = false;
inline constexpr std::size_t kEmgRawSerialPlotterWindowSamples = 20;
inline constexpr uint32_t kEmgRawSerialPlotterIntervalMs = 50;

// MPU-6050 기본 I2C 설정값. 보드 배선에 따라 SDA/SCL은 실제 연결값으로 바꿔야 한다.
inline constexpr int kImuI2cPort = 0;
inline constexpr int kImuI2cSdaGpio = 8;
inline constexpr int kImuI2cSclGpio = 9;
inline constexpr uint32_t kImuI2cClockHz = 400000;
inline constexpr uint8_t kMpu6050Address = 0x68;

inline constexpr uint32_t kFlagMockData = 1U << 0;
inline constexpr uint32_t kFlagCalibrationReady = 1U << 1;
inline constexpr uint32_t kFlagMotionDetected = 1U << 2;

}  // namespace mvp

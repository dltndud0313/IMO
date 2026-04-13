// 패킷 스키마, 샘플링 주기, 경량 처리 기본값을 한곳에 모은 설정 파일.
#pragma once

#include <cstddef>
#include <cstdint>

namespace mvp {

inline constexpr char kPacketSchema[] = "emg-glass.v1";
inline constexpr uint32_t kSerialBaudRate = 115200;
inline constexpr uint32_t kSampleIntervalMs = 20;
inline constexpr std::size_t kEmgMovingAverageWindow = 5;
inline constexpr std::size_t kEmgRmsWindow = 8;
inline constexpr std::size_t kEmgHistoryWindow = 16;
inline constexpr std::size_t kCalibrationSampleCount = 32;
inline constexpr float kActivationThreshold = 0.35F;
inline constexpr float kImuSmoothingAlpha = 0.35F;
inline constexpr float kMotionDetectionThreshold = 0.08F;

inline constexpr uint32_t kFlagMockData = 1U << 0;
inline constexpr uint32_t kFlagCalibrationReady = 1U << 1;
inline constexpr uint32_t kFlagMotionDetected = 1U << 2;

}  // namespace mvp

// 펌웨어 로직과 host-side 테스트가 함께 쓰는 공용 런타임 타입 정의.
#pragma once

#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

namespace mvp {

inline constexpr std::size_t kEmgChannelCount = 4;
inline constexpr std::size_t kImuSensorCount = 3;
inline constexpr std::size_t kAxisCount = 3;

enum class PacketFormat : uint8_t {
    JSON_V1 = 1,
    BINARY_V2 = 2,
};

enum class RuntimeState : uint8_t {
    IDLE = 0,
    STREAMING,
    ERROR,
};

enum class RuntimeEvent : uint8_t {
    ARM_STREAMING = 0,
    STOP_STREAMING,
    SENSOR_FAULT,
    RESET,
};

struct EmgSample {
    uint32_t timestamp_ms {0};
    std::array<float, kEmgChannelCount> channels {};
};

struct ImuSample {
    std::array<float, kAxisCount> accel {};
    std::array<float, kAxisCount> gyro {};
};

struct SensorFrame {
    EmgSample emg {};
    std::array<ImuSample, kImuSensorCount> imus {};
};

struct EmgProcessingResult {
    std::array<float, kEmgChannelCount> moving_average {};
    std::array<float, kEmgChannelCount> rms {};
    std::array<float, kEmgChannelCount> display {};
    std::array<bool, kEmgChannelCount> active {};
};

struct ImuProcessingResult {
    std::array<float, kAxisCount> accel_smoothed {};
    std::array<float, kAxisCount> gyro_smoothed {};
    float motion_delta {0.0F};
};

struct OutputPacket {
    std::string schema;
    uint32_t seq {0};
    uint32_t timestamp_ms {0};
    std::array<float, kEmgChannelCount> emg {};
    std::array<ImuSample, kImuSensorCount> imus {};
    std::string state;
    uint32_t flags {0};
    std::optional<int32_t> rep_index {};
};

inline const char* to_string(RuntimeState state) {
    switch (state) {
        case RuntimeState::IDLE:
            return "IDLE";
        case RuntimeState::STREAMING:
            return "STREAMING";
        case RuntimeState::ERROR:
            return "ERROR";
    }

    return "ERROR";
}

inline RuntimeState runtime_state_from_string(std::string_view value) {
    if (value == "IDLE") {
        return RuntimeState::IDLE;
    }
    if (value == "STREAMING") {
        return RuntimeState::STREAMING;
    }

    return RuntimeState::ERROR;
}

}  // namespace mvp

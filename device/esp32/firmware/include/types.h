// 펌웨어 로직과 host-side 테스트가 함께 쓰는 공용 런타임 타입 정의.
#pragma once

#include <array>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

namespace mvp {

inline constexpr std::size_t kEmgChannelCount = 3;
inline constexpr std::size_t kAxisCount = 3;

enum class PacketFormat : uint8_t {
    JSON_V1 = 1,
    BINARY_V2 = 2,
};

enum class RuntimeState : uint8_t {
    IDLE = 0,
    CALIBRATION_REST,
    CALIBRATION_MVC,
    READY,
    STREAMING,
    ERROR,
};

enum class RuntimeEvent : uint8_t {
    BEGIN_REST_CALIBRATION = 0,
    COMPLETE_REST_CALIBRATION,
    BEGIN_MVC_CALIBRATION,
    COMPLETE_MVC_CALIBRATION,
    ARM_STREAMING,
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
    ImuSample imu {};
};

struct CalibrationProfile {
    std::array<float, kEmgChannelCount> rest_baseline {};
    std::array<float, kEmgChannelCount> mvc_peak {1.0F, 1.0F, 1.0F};
    std::array<float, kEmgChannelCount> mvc_reference {1.0F, 1.0F, 1.0F};
    bool rest_ready {false};
    bool mvc_ready {false};
};

struct EmgProcessingResult {
    std::array<float, kEmgChannelCount> moving_average {};
    std::array<float, kEmgChannelCount> rms {};
    std::array<float, kEmgChannelCount> baseline_corrected {};
    std::array<float, kEmgChannelCount> normalized_instant {};
    std::array<float, kEmgChannelCount> normalized {};
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
    float emg_ch1 {0.0F};
    float emg_ch2 {0.0F};
    float emg_ch3 {0.0F};
    float acc_x {0.0F};
    float acc_y {0.0F};
    float acc_z {0.0F};
    float gyro_x {0.0F};
    float gyro_y {0.0F};
    float gyro_z {0.0F};
    std::string state;
    uint32_t flags {0};
    std::optional<int32_t> rep_index {};
};

inline const char* to_string(RuntimeState state) {
    switch (state) {
        case RuntimeState::IDLE:
            return "IDLE";
        case RuntimeState::CALIBRATION_REST:
            return "CALIBRATION_REST";
        case RuntimeState::CALIBRATION_MVC:
            return "CALIBRATION_MVC";
        case RuntimeState::READY:
            return "READY";
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
    if (value == "CALIBRATION_REST") {
        return RuntimeState::CALIBRATION_REST;
    }
    if (value == "CALIBRATION_MVC") {
        return RuntimeState::CALIBRATION_MVC;
    }
    if (value == "READY") {
        return RuntimeState::READY;
    }
    if (value == "STREAMING") {
        return RuntimeState::STREAMING;
    }

    return RuntimeState::ERROR;
}

}  // namespace mvp

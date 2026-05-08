// 쉬는 구간/수축 구간이 번갈아 나타나도록 만든 mock 파형 생성기.
#include "sensor_mock.h"

#include <cmath>

namespace mvp {
namespace {

float clamp_min(float value, float minimum) {
    return value < minimum ? minimum : value;
}

float clamp_range(float value, float minimum, float maximum) {
    if (value < minimum) {
        return minimum;
    }
    if (value > maximum) {
        return maximum;
    }
    return value;
}

float phase_ratio(uint32_t timestamp_ms, uint32_t period_ms) {
    return static_cast<float>(timestamp_ms % period_ms) / static_cast<float>(period_ms);
}

float pulse_envelope(float phase) {
    if (phase < 0.20F) {
        return 0.08F;
    }
    if (phase < 0.40F) {
        return 0.08F + ((phase - 0.20F) / 0.20F) * 0.72F;
    }
    if (phase < 0.70F) {
        return 0.80F;
    }
    if (phase < 0.90F) {
        return 0.80F - ((phase - 0.70F) / 0.20F) * 0.60F;
    }
    return 0.12F;
}

float oscillation(float phase, float frequency_scale) {
    return std::sin((phase * 6.2831853F * frequency_scale));
}

uint32_t scaled_period_ms(uint32_t base_period_ms, float speed) {
    return static_cast<uint32_t>(
        std::max(400.0F, static_cast<float>(base_period_ms) / clamp_min(speed, 0.1F))
    );
}

float scaled_envelope(float phase, float intensity) {
    return pulse_envelope(phase) * clamp_range(intensity, 0.2F, 2.0F);
}

SensorFrame build_default_frame(uint32_t timestamp_ms, const MockSensorConfig& config) {
    const float phase = phase_ratio(timestamp_ms, scaled_period_ms(4000U, config.speed));
    const float envelope = scaled_envelope(phase, config.intensity);
    const float fast_wave = oscillation(phase, 8.0F);
    const float slow_wave = oscillation(phase, 2.0F);

    SensorFrame frame;
    frame.emg.timestamp_ms = timestamp_ms;
    frame.emg.channels = {
        0.06F + envelope * (0.60F + 0.25F * fast_wave),
        0.05F + envelope * (0.52F + 0.18F * slow_wave),
        0.04F + envelope * (0.38F + 0.10F * fast_wave),
        0.03F + envelope * (0.32F + 0.12F * slow_wave),
    };

    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        const float imu_offset = static_cast<float>(imu_index) * 0.12F;
        const float imu_phase = phase + imu_offset;
        const float imu_fast_wave = oscillation(imu_phase, 7.0F);
        const float imu_slow_wave = oscillation(imu_phase, 2.5F);

        frame.imus[imu_index].accel = {
            0.10F * imu_slow_wave,
            0.22F * envelope,
            1.00F + 0.05F * imu_fast_wave,
        };
        frame.imus[imu_index].gyro = {
            0.22F * imu_fast_wave,
            0.24F * imu_slow_wave,
            0.15F * envelope,
        };
    }

    return frame;
}

SensorFrame build_bicep_curl_frame(uint32_t timestamp_ms, const MockSensorConfig& config) {
    const float phase = phase_ratio(timestamp_ms, scaled_period_ms(3200U, config.speed));
    const float envelope = scaled_envelope(phase, config.intensity);
    const float lift_wave = oscillation(phase, 1.0F);
    const float tension_wave = oscillation(phase, 5.0F);

    SensorFrame frame;
    frame.emg.timestamp_ms = timestamp_ms;
    frame.emg.channels = {
        0.03F + envelope * (0.78F + 0.08F * tension_wave),
        0.02F + envelope * (0.70F + 0.06F * lift_wave),
        0.015F + envelope * (0.38F + 0.05F * tension_wave),
        0.010F + envelope * (0.22F + 0.04F * lift_wave),
    };

    frame.imus[0].accel = {
        0.08F + 0.55F * envelope,
        -0.12F + 0.10F * lift_wave,
        0.92F - 0.38F * envelope,
    };
    frame.imus[0].gyro = {
        0.10F * tension_wave,
        1.35F * lift_wave,
        0.20F * envelope,
    };

    frame.imus[1].accel = {
        0.05F + 0.48F * envelope,
        -0.08F + 0.08F * lift_wave,
        0.95F - 0.31F * envelope,
    };
    frame.imus[1].gyro = {
        0.08F * tension_wave,
        1.10F * lift_wave,
        0.15F * envelope,
    };

    frame.imus[2].accel = {
        0.02F + 0.12F * envelope,
        0.03F * tension_wave,
        0.99F - 0.08F * envelope,
    };
    frame.imus[2].gyro = {
        0.04F * tension_wave,
        0.18F * lift_wave,
        0.06F * envelope,
    };

    return frame;
}

SensorFrame build_push_up_frame(uint32_t timestamp_ms, const MockSensorConfig& config) {
    const float phase = phase_ratio(timestamp_ms, scaled_period_ms(2800U, config.speed));
    const float envelope = scaled_envelope(phase, config.intensity);
    const float body_wave = oscillation(phase, 1.0F);
    const float stabilizer_wave = oscillation(phase, 4.0F);

    SensorFrame frame;
    frame.emg.timestamp_ms = timestamp_ms;
    frame.emg.channels = {
        0.04F + envelope * (0.62F + 0.05F * stabilizer_wave),
        0.04F + envelope * (0.58F + 0.05F * body_wave),
        0.03F + envelope * (0.54F + 0.04F * stabilizer_wave),
        0.03F + envelope * (0.50F + 0.04F * body_wave),
    };

    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        const float offset = static_cast<float>(imu_index) * 0.05F;
        frame.imus[imu_index].accel = {
            -0.10F + 0.04F * stabilizer_wave,
            0.18F + 0.32F * envelope + offset,
            0.96F - 0.18F * envelope,
        };
        frame.imus[imu_index].gyro = {
            0.65F * body_wave,
            0.10F * stabilizer_wave,
            0.12F * envelope,
        };
    }

    return frame;
}

SensorFrame build_squat_frame(uint32_t timestamp_ms, const MockSensorConfig& config) {
    const float phase = phase_ratio(timestamp_ms, scaled_period_ms(3000U, config.speed));
    const float envelope = scaled_envelope(phase, config.intensity);
    const float body_wave = oscillation(phase, 1.0F);
    const float stabilizer_wave = oscillation(phase, 3.0F);

    SensorFrame frame;
    frame.emg.timestamp_ms = timestamp_ms;
    frame.emg.channels = {
        0.02F + envelope * (0.28F + 0.04F * stabilizer_wave),
        0.02F + envelope * (0.30F + 0.04F * body_wave),
        0.05F + envelope * (0.72F + 0.06F * stabilizer_wave),
        0.05F + envelope * (0.76F + 0.06F * body_wave),
    };

    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        const float offset = static_cast<float>(imu_index) * 0.04F;
        frame.imus[imu_index].accel = {
            0.03F * stabilizer_wave,
            -0.08F + 0.24F * envelope + offset,
            0.98F - 0.26F * envelope,
        };
        frame.imus[imu_index].gyro = {
            0.18F * stabilizer_wave,
            0.82F * body_wave,
            0.10F * envelope,
        };
    }

    return frame;
}

SensorFrame build_lateral_raise_frame(uint32_t timestamp_ms, const MockSensorConfig& config) {
    const float phase = phase_ratio(timestamp_ms, scaled_period_ms(3200U, config.speed));
    const float envelope = scaled_envelope(phase, config.intensity);
    const float lift_wave = oscillation(phase, 1.0F);
    const float tension_wave = oscillation(phase, 4.5F);

    SensorFrame frame;
    frame.emg.timestamp_ms = timestamp_ms;
    frame.emg.channels = {
        0.03F + envelope * (0.42F + 0.05F * tension_wave),
        0.03F + envelope * (0.42F + 0.05F * tension_wave),
        0.03F + envelope * (0.68F + 0.05F * lift_wave),
        0.03F + envelope * (0.68F + 0.05F * lift_wave),
    };

    frame.imus[0].accel = {
        0.10F + 0.42F * envelope,
        0.04F * tension_wave,
        0.96F - 0.30F * envelope,
    };
    frame.imus[0].gyro = {
        1.05F * lift_wave,
        0.06F * tension_wave,
        0.10F * envelope,
    };

    frame.imus[1].accel = {
        -0.10F - 0.42F * envelope,
        0.04F * tension_wave,
        0.96F - 0.30F * envelope,
    };
    frame.imus[1].gyro = {
        -1.05F * lift_wave,
        0.06F * tension_wave,
        0.10F * envelope,
    };

    frame.imus[2].accel = {
        0.02F * tension_wave,
        0.02F * lift_wave,
        0.99F - 0.06F * envelope,
    };
    frame.imus[2].gyro = {
        0.04F * tension_wave,
        0.10F * lift_wave,
        0.04F * envelope,
    };

    return frame;
}

uint32_t profile_base_period_ms(MockWorkoutProfile profile) {
    switch (profile) {
        case MockWorkoutProfile::BICEP_CURL:
            return 3200U;
        case MockWorkoutProfile::PUSH_UP:
            return 2800U;
        case MockWorkoutProfile::SQUAT:
            return 3000U;
        case MockWorkoutProfile::LATERAL_RAISE:
            return 3200U;
        case MockWorkoutProfile::DEFAULT:
        default:
            return 4000U;
    }
}

}  // namespace

SensorFrame MockSensorSource::read_frame(uint32_t timestamp_ms) {
    switch (config_.profile) {
        case MockWorkoutProfile::BICEP_CURL:
            return build_bicep_curl_frame(timestamp_ms, config_);
        case MockWorkoutProfile::PUSH_UP:
            return build_push_up_frame(timestamp_ms, config_);
        case MockWorkoutProfile::SQUAT:
            return build_squat_frame(timestamp_ms, config_);
        case MockWorkoutProfile::LATERAL_RAISE:
            return build_lateral_raise_frame(timestamp_ms, config_);
        case MockWorkoutProfile::DEFAULT:
        default:
            return build_default_frame(timestamp_ms, config_);
    }
}

}  // namespace mvp

// 쉬는 구간/수축 구간이 번갈아 나타나도록 만든 mock 파형 생성기.
#include "sensor_mock.h"

#include <cmath>

namespace mvp {
namespace {

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

}  // namespace

SensorFrame MockSensorSource::read_frame(uint32_t timestamp_ms) {
    const float phase = phase_ratio(timestamp_ms, 4000U);
    const float envelope = pulse_envelope(phase);
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

}  // namespace mvp

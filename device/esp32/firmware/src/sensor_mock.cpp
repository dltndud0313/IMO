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
    };

    frame.imu.accel = {
        0.08F * slow_wave,
        0.20F * envelope,
        1.00F + 0.04F * fast_wave,
    };
    frame.imu.gyro = {
        0.18F * fast_wave,
        0.26F * slow_wave,
        0.12F * envelope,
    };

    return frame;
}

}  // namespace mvp

// 무거운 센서 융합 대신 smoothing + 간단한 motion score를 사용하는 IMU 처리 구현.
#include "imu_processor.h"

#include <cmath>

#include "config.h"

namespace mvp {

ImuProcessingResult ImuProcessor::process(const ImuSample& sample) {
    ImuProcessingResult result;

    if (!initialized_) {
        smoothed_ = sample;
        initialized_ = true;
    } else {
        for (std::size_t axis = 0; axis < kAxisCount; ++axis) {
            smoothed_.accel[axis] =
                (sample.accel[axis] * kImuSmoothingAlpha) +
                (smoothed_.accel[axis] * (1.0F - kImuSmoothingAlpha));
            smoothed_.gyro[axis] =
                (sample.gyro[axis] * kImuSmoothingAlpha) +
                (smoothed_.gyro[axis] * (1.0F - kImuSmoothingAlpha));
        }
    }

    float motion_sum = 0.0F;
    for (std::size_t axis = 0; axis < kAxisCount; ++axis) {
        result.accel_smoothed[axis] = smoothed_.accel[axis];
        result.gyro_smoothed[axis] = smoothed_.gyro[axis];
        motion_sum += std::fabs(smoothed_.gyro[axis]);
    }

    result.motion_delta = motion_sum / static_cast<float>(kAxisCount);
    return result;
}

void ImuProcessor::reset() {
    smoothed_ = {};
    initialized_ = false;
}

}  // namespace mvp

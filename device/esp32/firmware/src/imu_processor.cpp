// 무거운 센서 융합 대신 smoothing + 간단한 motion score를 사용하는 IMU 처리 구현.
#include "imu_processor.h"

#include <cmath>

#include "config.h"

namespace mvp {

ImuProcessingResult ImuProcessor::process(const ImuSample& sample) {
    ImuProcessingResult result;

    if (!initialized_) {
        // 첫 샘플은 이전 값이 없으므로 그대로 초기 smoothing 기준점으로 삼는다.
        smoothed_ = sample;
        initialized_ = true;
    } else {
        for (std::size_t axis = 0; axis < kAxisCount; ++axis) {
            // 지수이동평균(EMA) 형태로 가속도/자이로를 부드럽게 만든다.
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
        // MVP 단계에서는 자이로 절대값 평균을 간단한 움직임 점수로 사용한다.
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

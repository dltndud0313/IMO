// 무거운 센서 융합 대신 smoothing + 간단한 motion score를 사용하는 IMU 처리 구현.
#include "imu_processor.h"

#include <cmath>

#include "config.h"

namespace mvp {

ImuProcessingResult ImuProcessor::process(const ImuSample& sample) {
    ImuProcessingResult result;
    ImuSample unbiased_sample = sample;

    if (!gyro_bias_ready_) {
        // 부팅 직후 정지 상태 몇 프레임을 평균내 자이로 영점 오프셋을 추정한다.
        for (std::size_t axis = 0; axis < kAxisCount; ++axis) {
            gyro_bias_accumulator_[axis] += sample.gyro[axis];
        }
        ++gyro_bias_samples_;

        for (std::size_t axis = 0; axis < kAxisCount; ++axis) {
            gyro_bias_[axis] = gyro_bias_accumulator_[axis] / static_cast<float>(gyro_bias_samples_);
        }

        if (gyro_bias_samples_ >= kImuGyroBiasCalibrationSamples) {
            gyro_bias_ready_ = true;
        }
    }

    for (std::size_t axis = 0; axis < kAxisCount; ++axis) {
        unbiased_sample.gyro[axis] = sample.gyro[axis] - gyro_bias_[axis];
    }

    if (!initialized_) {
        // 첫 샘플은 이전 값이 없으므로 그대로 초기 smoothing 기준점으로 삼는다.
        smoothed_ = unbiased_sample;
        initialized_ = true;
    } else {
        for (std::size_t axis = 0; axis < kAxisCount; ++axis) {
            // 지수이동평균(EMA) 형태로 가속도/자이로를 부드럽게 만든다.
            smoothed_.accel[axis] =
                (unbiased_sample.accel[axis] * kImuSmoothingAlpha) +
                (smoothed_.accel[axis] * (1.0F - kImuSmoothingAlpha));
            smoothed_.gyro[axis] =
                (unbiased_sample.gyro[axis] * kImuSmoothingAlpha) +
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
    gyro_bias_ = {};
    gyro_bias_accumulator_ = {};
    smoothed_ = {};
    gyro_bias_samples_ = 0;
    initialized_ = false;
    gyro_bias_ready_ = false;
}

}  // namespace mvp

// rest baseline과 MVC peak를 저장해 이후 EMG 값을 정규화할 수 있게 하는 구현.
#include "calibration.h"

#include <algorithm>

#include "config.h"

namespace mvp {

void CalibrationManager::reset() {
    profile_ = {};
    profile_.mvc_peak.fill(1.0F);
    rest_accumulator_.fill(0.0F);
    rest_samples_ = 0;
    mvc_samples_ = 0;
}

void CalibrationManager::begin_rest_capture() {
    rest_accumulator_.fill(0.0F);
    rest_samples_ = 0;
    profile_.rest_baseline.fill(0.0F);
    profile_.rest_ready = false;
}

void CalibrationManager::begin_mvc_capture() {
    mvc_samples_ = 0;
    profile_.mvc_peak.fill(0.0F);
    profile_.mvc_ready = false;
}

void CalibrationManager::push_rest_sample(const std::array<float, kEmgChannelCount>& sample) {
    if (rest_complete()) {
        return;
    }

    for (std::size_t channel = 0; channel < kEmgChannelCount; ++channel) {
        rest_accumulator_[channel] += sample[channel];
    }

    ++rest_samples_;

    if (rest_complete()) {
        for (std::size_t channel = 0; channel < kEmgChannelCount; ++channel) {
            profile_.rest_baseline[channel] =
                rest_accumulator_[channel] / static_cast<float>(rest_samples_);
        }
        profile_.rest_ready = true;
    }
}

void CalibrationManager::push_mvc_sample(const std::array<float, kEmgChannelCount>& sample) {
    if (mvc_complete()) {
        return;
    }

    for (std::size_t channel = 0; channel < kEmgChannelCount; ++channel) {
        profile_.mvc_peak[channel] = std::max(profile_.mvc_peak[channel], sample[channel]);
    }

    ++mvc_samples_;

    if (mvc_complete()) {
        for (std::size_t channel = 0; channel < kEmgChannelCount; ++channel) {
            profile_.mvc_peak[channel] =
                std::max(profile_.mvc_peak[channel], profile_.rest_baseline[channel] + 0.05F);
        }
        profile_.mvc_ready = true;
    }
}

bool CalibrationManager::rest_complete() const {
    return rest_samples_ >= kCalibrationSampleCount;
}

bool CalibrationManager::mvc_complete() const {
    return mvc_samples_ >= kCalibrationSampleCount;
}

std::size_t CalibrationManager::rest_samples_collected() const {
    return rest_samples_;
}

std::size_t CalibrationManager::mvc_samples_collected() const {
    return mvc_samples_;
}

const CalibrationProfile& CalibrationManager::profile() const {
    return profile_;
}

}  // namespace mvp

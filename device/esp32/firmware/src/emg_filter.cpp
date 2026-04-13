// 하드웨어 도착 전 MVP 검증을 위해 경량화한 EMG 전처리 구현.
#include "emg_filter.h"

#include <algorithm>
#include <cmath>
#include <numeric>

#include "config.h"

namespace mvp {
namespace {

void trim_history(std::deque<float>* samples) {
    while (samples->size() > kEmgHistoryWindow) {
        samples->pop_front();
    }
}

}  // namespace

float compute_moving_average(const std::deque<float>& samples, std::size_t window) {
    if (samples.empty() || window == 0) {
        return 0.0F;
    }

    const std::size_t active_window = std::min(window, samples.size());
    float sum = 0.0F;
    for (std::size_t index = samples.size() - active_window; index < samples.size(); ++index) {
        sum += samples[index];
    }

    return sum / static_cast<float>(active_window);
}

float compute_rms(const std::deque<float>& samples, std::size_t window) {
    if (samples.empty() || window == 0) {
        return 0.0F;
    }

    const std::size_t active_window = std::min(window, samples.size());
    float sum_squares = 0.0F;
    for (std::size_t index = samples.size() - active_window; index < samples.size(); ++index) {
        sum_squares += samples[index] * samples[index];
    }

    return std::sqrt(sum_squares / static_cast<float>(active_window));
}

float apply_baseline(float value, float baseline) {
    return std::max(0.0F, value - baseline);
}

float normalize_activation(float value, float min_value, float max_value) {
    if (max_value <= min_value) {
        return 0.0F;
    }

    const float normalized = (value - min_value) / (max_value - min_value);
    return std::clamp(normalized, 0.0F, 1.0F);
}

bool threshold_active(float normalized_value, float threshold) {
    return normalized_value >= threshold;
}

EmgProcessingResult EmgFilter::process(
    const std::array<float, kEmgChannelCount>& raw,
    const CalibrationProfile& calibration_profile
) {
    EmgProcessingResult result;

    for (std::size_t channel = 0; channel < kEmgChannelCount; ++channel) {
        sample_history_[channel].push_back(raw[channel]);
        trim_history(&sample_history_[channel]);

        result.moving_average[channel] =
            compute_moving_average(sample_history_[channel], kEmgMovingAverageWindow);
        result.rms[channel] = compute_rms(sample_history_[channel], kEmgRmsWindow);
        result.baseline_corrected[channel] = apply_baseline(
            result.rms[channel],
            calibration_profile.rest_baseline[channel]
        );

        const float reference_max = calibration_profile.mvc_ready
            ? calibration_profile.mvc_peak[channel]
            : 1.0F;
        result.normalized[channel] = normalize_activation(
            result.rms[channel],
            calibration_profile.rest_baseline[channel],
            reference_max
        );
        result.active[channel] =
            threshold_active(result.normalized[channel], kActivationThreshold);
    }

    return result;
}

void EmgFilter::reset() {
    for (auto& history : sample_history_) {
        history.clear();
    }
}

}  // namespace mvp

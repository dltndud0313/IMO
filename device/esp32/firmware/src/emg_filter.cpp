// 하드웨어 도착 전 MVP 검증을 위해 경량화한 EMG 전처리 구현.
#include "emg_filter.h"

#include <algorithm>
#include <cmath>
#include <numeric>

#include "config.h"

namespace mvp {
namespace {

void trim_history(std::deque<float>* samples) {
    // 최근 N개만 유지해야 이동평균/RMS 계산량이 고정된다.
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
    // 최신 샘플 위주로 평균을 내서 순간 튐을 줄인다.
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
    // RMS는 부호가 흔들리는 신호를 "평균적인 세기"로 보는 데 더 적합하다.
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

    // rest~MVC 구간을 0~1로 맞춰 채널/사용자마다 비교하기 쉬운 값으로 바꾼다.
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
        // 채널별로 원시값 -> smoothing -> RMS -> baseline 보정 -> 정규화 순서로 처리한다.
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
        // MVC가 아직 없으면 1.0을 임시 상한으로 써서 mock 단계에서도 파이프라인을 유지한다.
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

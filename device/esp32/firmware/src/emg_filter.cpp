// 하드웨어 도착 전 MVP 검증을 위해 경량화한 EMG 전처리 구현.
#include "emg_filter.h"

#include <algorithm>
#include <cmath>
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

float smooth_display(float current_value, float previous_value, float attack_alpha, float release_alpha) {
    const float alpha = current_value >= previous_value ? attack_alpha : release_alpha;
    return (current_value * alpha) + (previous_value * (1.0F - alpha));
}

bool threshold_active(
    float value,
    bool was_active,
    float threshold_on,
    float threshold_off
) {
    if (was_active) {
        return value >= threshold_off;
    }

    return value >= threshold_on;
}

EmgProcessingResult EmgFilter::process(
    const std::array<float, kEmgChannelCount>& raw
) {
    EmgProcessingResult result;

    for (std::size_t channel = 0; channel < kEmgChannelCount; ++channel) {
        if (raw[channel] >= kEmgDetachInputThreshold) {
            sample_history_[channel].clear();
            result.moving_average[channel] = raw[channel];
            result.rms[channel] = raw[channel];
            result.display[channel] = kAnalogEmgDetachFrameValue;
            result.active[channel] = true;
            display_history_[channel] = 0.0F;
            display_hold_count_[channel] = 0U;
            active_state_[channel] = false;
            detached_state_[channel] = true;
            continue;
        }

        if (detached_state_[channel]) {
            sample_history_[channel].clear();
            display_history_[channel] = 0.0F;
            display_hold_count_[channel] = 0U;
            active_state_[channel] = false;
            detached_state_[channel] = false;
        }

        // ESP32에서는 신호 세기(RMS)와 표시 안정화만 담당하고 캘리브레이션은 Pi로 위임한다.
        sample_history_[channel].push_back(raw[channel]);
        trim_history(&sample_history_[channel]);

        result.moving_average[channel] =
            compute_moving_average(sample_history_[channel], kEmgMovingAverageWindow);
        result.rms[channel] = compute_rms(sample_history_[channel], kEmgRmsWindow);

        // 센서 소스가 이미 양수 envelope를 만든다. 표시값은 RMS보다 이동평균을 써서
        // 유지 중 작은 흔들림이 과하게 튀지 않게 한다.
        float display_base = result.moving_average[channel] - kEmgDisplayNoiseFloor;
        if (display_base < 0.0F) {
            display_base = 0.0F;
        }
        display_base *= kEmgDisplayGain;
        display_base = std::clamp(display_base, 0.0F, kEmgDisplaySignalMax);
        if (display_base < kEmgDisplayZeroClamp) {
            display_base = 0.0F;
        }

        if (raw[channel] >= kEmgDisplayHoldRawThreshold) {
            display_hold_count_[channel] = kEmgDisplayHoldFrames;
        } else if (display_hold_count_[channel] > 0U) {
            --display_hold_count_[channel];
        }

        if (
            display_hold_count_[channel] > 0U &&
            display_base < display_history_[channel] &&
            display_history_[channel] >= kEmgDisplayHoldDisplayThreshold
        ) {
            // EMG는 유지 수축 중에도 짧게 꺼지는 구간이 있어 게이지가 바로 꺼지지 않게 한다.
            display_base = display_history_[channel];
        }

        const float release_alpha = display_base == 0.0F
            ? kEmgDisplayZeroReleaseAlpha
            : kEmgDisplayReleaseAlpha;
        result.display[channel] = smooth_display(
            display_base,
            display_history_[channel],
            kEmgDisplayAttackAlpha,
            release_alpha
        );
        if (display_base == 0.0F && result.display[channel] < kEmgDisplayZeroClamp) {
            result.display[channel] = 0.0F;
        }
        display_history_[channel] = result.display[channel];
        const float active_value = result.display[channel] <= kEmgRestDisplayThreshold
            ? 0.0F
            : result.display[channel];
        result.active[channel] = threshold_active(
            active_value,
            active_state_[channel],
            kActivationThresholdOn,
            kActivationThresholdOff
        );
        active_state_[channel] = result.active[channel];
    }

    return result;
}

void EmgFilter::reset() {
    for (auto& history : sample_history_) {
        history.clear();
    }
    display_history_.fill(0.0F);
    display_hold_count_.fill(0U);
    active_state_.fill(false);
    detached_state_.fill(false);
}

}  // namespace mvp

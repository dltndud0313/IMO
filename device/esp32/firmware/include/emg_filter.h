// EMG 전처리(이동평균, RMS, baseline 보정, 활성도 정규화) 인터페이스.
#pragma once

#include <array>
#include <cstddef>
#include <deque>

#include "types.h"

namespace mvp {

float compute_moving_average(const std::deque<float>& samples, std::size_t window);
float compute_rms(const std::deque<float>& samples, std::size_t window);
float apply_baseline(float value, float baseline);
float normalize_activation(float value, float min_value, float max_value);
float smooth_activation(float current_value, float previous_value, float attack_alpha, float release_alpha);
bool threshold_active(float normalized_value, bool was_active, float threshold_on, float threshold_off);

class EmgFilter {
  public:
    EmgFilter() = default;

    EmgProcessingResult process(
        const std::array<float, kEmgChannelCount>& raw,
        const CalibrationProfile& calibration_profile
    );

    void reset();

  private:
    std::array<std::deque<float>, kEmgChannelCount> sample_history_ {};
    std::array<float, kEmgChannelCount> activation_history_ {};
    std::array<float, kEmgChannelCount> display_history_ {};
    std::array<bool, kEmgChannelCount> active_state_ {};
};

}  // namespace mvp

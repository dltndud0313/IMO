// EMG 전처리(이동평균, RMS, 표시용 smoothing) 인터페이스.
#pragma once

#include <array>
#include <cstddef>
#include <deque>

#include "types.h"

namespace mvp {

float compute_moving_average(const std::deque<float>& samples, std::size_t window);
float compute_rms(const std::deque<float>& samples, std::size_t window);
float smooth_display(float current_value, float previous_value, float attack_alpha, float release_alpha);
bool threshold_active(float value, bool was_active, float threshold_on, float threshold_off);

class EmgFilter {
  public:
    EmgFilter() = default;

    EmgProcessingResult process(
        const std::array<float, kEmgChannelCount>& raw
    );

    void reset();

  private:
    std::array<std::deque<float>, kEmgChannelCount> sample_history_ {};
    std::array<float, kEmgChannelCount> display_history_ {};
    std::array<std::size_t, kEmgChannelCount> display_hold_count_ {};
    std::array<bool, kEmgChannelCount> active_state_ {};
    std::array<bool, kEmgChannelCount> detached_state_ {};
};

}  // namespace mvp

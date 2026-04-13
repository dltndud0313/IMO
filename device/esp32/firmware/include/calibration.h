// 반복된 EMG 샘플을 rest/MVC 기준 프로필로 만드는 캘리브레이션 인터페이스.
#pragma once

#include <array>
#include <cstddef>

#include "types.h"

namespace mvp {

class CalibrationManager {
  public:
    CalibrationManager() = default;

    void reset();
    void begin_rest_capture();
    void begin_mvc_capture();
    void push_rest_sample(const std::array<float, kEmgChannelCount>& sample);
    void push_mvc_sample(const std::array<float, kEmgChannelCount>& sample);

    bool rest_complete() const;
    bool mvc_complete() const;
    std::size_t rest_samples_collected() const;
    std::size_t mvc_samples_collected() const;
    const CalibrationProfile& profile() const;

  private:
    CalibrationProfile profile_ {};
    std::array<float, kEmgChannelCount> rest_accumulator_ {};
    std::size_t rest_samples_ {0};
    std::size_t mvc_samples_ {0};
};

}  // namespace mvp

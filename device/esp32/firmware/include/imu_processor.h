// Pi4급에서도 부담이 적도록 설계한 IMU smoothing/움직임 점수 계산 인터페이스.
#pragma once

#include <array>
#include <cstddef>

#include "types.h"

namespace mvp {

class ImuProcessor {
  public:
    ImuProcessor() = default;

    ImuProcessingResult process(const ImuSample& sample);
    bool gyro_bias_ready() const;
    void reset();

  private:
    std::array<float, kAxisCount> gyro_bias_ {};
    std::array<float, kAxisCount> gyro_bias_accumulator_ {};
    ImuSample smoothed_ {};
    std::size_t gyro_bias_samples_ {0};
    bool initialized_ {false};
    bool gyro_bias_ready_ {false};
};

}  // namespace mvp

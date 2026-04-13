// Pi4급에서도 부담이 적도록 설계한 IMU smoothing/움직임 점수 계산 인터페이스.
#pragma once

#include "types.h"

namespace mvp {

class ImuProcessor {
  public:
    ImuProcessor() = default;

    ImuProcessingResult process(const ImuSample& sample);
    void reset();

  private:
    ImuSample smoothed_ {};
    bool initialized_ {false};
};

}  // namespace mvp

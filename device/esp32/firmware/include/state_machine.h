// ESP32는 수집/전송 장치로 단순화하고, 상태머신은 스트리밍/오류 전이만 관리한다.
#pragma once

#include "types.h"

namespace mvp {

class StateMachine {
  public:
    RuntimeState state() const;
    bool handle_event(RuntimeEvent event);
    void reset();

  private:
    RuntimeState state_ {RuntimeState::STREAMING};
};

}  // namespace mvp

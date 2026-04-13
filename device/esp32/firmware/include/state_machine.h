// 캘리브레이션 단계와 스트리밍 단계를 명확히 관리하는 상태머신 인터페이스.
#pragma once

#include "types.h"

namespace mvp {

class StateMachine {
  public:
    RuntimeState state() const;
    bool handle_event(RuntimeEvent event);
    void reset();

  private:
    RuntimeState state_ {RuntimeState::IDLE};
};

}  // namespace mvp

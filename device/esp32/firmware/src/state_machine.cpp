// 상태 전이를 명시적으로 관리해 초기 하드웨어 bring-up 단계에서도 동작 예측성을 확보.
#include "state_machine.h"

namespace mvp {

RuntimeState StateMachine::state() const {
    return state_;
}

bool StateMachine::handle_event(RuntimeEvent event) {
    // RESET과 SENSOR_FAULT는 현재 상태와 상관없이 항상 우선 처리한다.
    switch (event) {
        case RuntimeEvent::RESET:
            state_ = RuntimeState::STREAMING;
            return true;
        case RuntimeEvent::SENSOR_FAULT:
            state_ = RuntimeState::ERROR;
            return true;
        case RuntimeEvent::ARM_STREAMING:
            state_ = RuntimeState::STREAMING;
            return true;
        case RuntimeEvent::STOP_STREAMING:
            state_ = RuntimeState::IDLE;
            return true;
        default:
            break;
    }

    return false;
}

void StateMachine::reset() {
    state_ = RuntimeState::STREAMING;
}

}  // namespace mvp

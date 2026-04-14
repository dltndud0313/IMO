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
            state_ = RuntimeState::IDLE;
            return true;
        case RuntimeEvent::SENSOR_FAULT:
            state_ = RuntimeState::ERROR;
            return true;
        default:
            break;
    }

    switch (state_) {
        case RuntimeState::IDLE:
            if (event == RuntimeEvent::BEGIN_REST_CALIBRATION) {
                state_ = RuntimeState::CALIBRATION_REST;
                return true;
            }
            return false;
        case RuntimeState::CALIBRATION_REST:
            if (event == RuntimeEvent::COMPLETE_REST_CALIBRATION) {
                state_ = RuntimeState::CALIBRATION_MVC;
                return true;
            }
            return false;
        case RuntimeState::CALIBRATION_MVC:
            if (event == RuntimeEvent::COMPLETE_MVC_CALIBRATION) {
                state_ = RuntimeState::READY;
                return true;
            }
            return false;
        case RuntimeState::READY:
            if (event == RuntimeEvent::ARM_STREAMING) {
                state_ = RuntimeState::STREAMING;
                return true;
            }
            // READY 상태에서는 필요하면 캘리브레이션을 다시 시작할 수 있게 열어둔다.
            if (event == RuntimeEvent::BEGIN_REST_CALIBRATION) {
                state_ = RuntimeState::CALIBRATION_REST;
                return true;
            }
            return false;
        case RuntimeState::STREAMING:
            if (event == RuntimeEvent::STOP_STREAMING) {
                state_ = RuntimeState::READY;
                return true;
            }
            return false;
        case RuntimeState::ERROR:
            return false;
    }

    return false;
}

void StateMachine::reset() {
    state_ = RuntimeState::IDLE;
}

}  // namespace mvp

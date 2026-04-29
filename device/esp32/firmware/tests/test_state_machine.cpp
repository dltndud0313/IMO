// 상태 전이가 단순화된 규칙대로 동작하는지 확인한다.
#include "state_machine.h"
#include "test_utils.h"

void run_test_state_machine() {
    mvp::StateMachine state_machine;
    expect_true(
        state_machine.state() == mvp::RuntimeState::STREAMING,
        "initial state should be STREAMING"
    );

    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::STOP_STREAMING),
        "STREAMING -> IDLE should be allowed"
    );
    expect_true(
        state_machine.state() == mvp::RuntimeState::IDLE,
        "state should be IDLE"
    );

    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::ARM_STREAMING),
        "IDLE -> STREAMING should be allowed"
    );
    expect_true(
        state_machine.state() == mvp::RuntimeState::STREAMING,
        "state should be STREAMING"
    );

    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::SENSOR_FAULT),
        "sensor fault should move to ERROR"
    );
    expect_true(
        state_machine.state() == mvp::RuntimeState::ERROR,
        "state should be ERROR after sensor fault"
    );

    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::RESET),
        "reset should move back to STREAMING"
    );
    expect_true(
        state_machine.state() == mvp::RuntimeState::STREAMING,
        "state should be STREAMING after reset"
    );
}

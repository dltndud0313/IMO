// 상태 전이가 명시된 규칙대로 동작하는지 확인해 bring-up 시 예측 가능성을 확보한다.
#include "state_machine.h"
#include "test_utils.h"

void run_test_state_machine() {
    mvp::StateMachine state_machine;
    expect_true(
        state_machine.state() == mvp::RuntimeState::IDLE,
        "initial state should be IDLE"
    );

    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::BEGIN_REST_CALIBRATION),
        "IDLE -> CALIBRATION_REST should be allowed"
    );
    expect_true(
        state_machine.state() == mvp::RuntimeState::CALIBRATION_REST,
        "state should be CALIBRATION_REST"
    );

    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::COMPLETE_REST_CALIBRATION),
        "rest completion should move to MVC calibration"
    );
    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::COMPLETE_MVC_CALIBRATION),
        "mvc completion should move to READY"
    );
    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::ARM_STREAMING),
        "READY -> STREAMING should be allowed"
    );
    expect_true(
        state_machine.state() == mvp::RuntimeState::STREAMING,
        "state should be STREAMING"
    );
    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::STOP_STREAMING),
        "STREAMING -> READY should be allowed"
    );
    expect_true(
        state_machine.handle_event(mvp::RuntimeEvent::SENSOR_FAULT),
        "sensor fault should move to ERROR"
    );
    expect_true(
        state_machine.state() == mvp::RuntimeState::ERROR,
        "state should be ERROR after sensor fault"
    );
}

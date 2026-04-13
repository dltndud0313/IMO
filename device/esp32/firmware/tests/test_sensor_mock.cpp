// mock 센서 값이 시간에 따라 변화해 파이프라인을 실제처럼 자극하는지 확인한다.
#include "sensor_mock.h"
#include "test_utils.h"

void run_test_sensor_mock() {
    mvp::MockSensorSource sensor;
    const auto rest_frame = sensor.read_frame(0);
    const auto active_frame = sensor.read_frame(2000);

    expect_true(
        active_frame.emg.channels[0] != rest_frame.emg.channels[0],
        "mock sensor should vary EMG values over time"
    );
    expect_true(
        active_frame.imu.gyro[1] != rest_frame.imu.gyro[1],
        "mock sensor should vary IMU values over time"
    );
}

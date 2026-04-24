// IMU 처리기에서 자이로 bias를 제거하고 움직임이 생기면 다시 반응하는지 확인한다.
#include "config.h"
#include "imu_processor.h"
#include "test_utils.h"

void run_test_imu_processor() {
    mvp::ImuProcessor processor;
    mvp::ImuSample stationary_sample;
    stationary_sample.accel = {1.0F, 0.0F, 0.0F};
    stationary_sample.gyro = {2.5F, -1.5F, 0.5F};

    mvp::ImuProcessingResult result;
    for (std::size_t index = 0; index < mvp::kImuGyroBiasCalibrationSamples; ++index) {
        result = processor.process(stationary_sample);
    }

    expect_near(result.gyro_smoothed[0], 0.0F, 0.05F, "gyro x should be near zero after bias calibration");
    expect_near(result.gyro_smoothed[1], 0.0F, 0.05F, "gyro y should be near zero after bias calibration");
    expect_near(result.gyro_smoothed[2], 0.0F, 0.05F, "gyro z should be near zero after bias calibration");
    expect_true(result.motion_delta < 0.05F, "stationary gyro should not look like motion after bias calibration");

    mvp::ImuSample moving_sample = stationary_sample;
    moving_sample.gyro = {5.5F, -1.5F, 0.5F};
    result = processor.process(moving_sample);

    expect_true(result.gyro_smoothed[0] > 0.5F, "gyro x should respond when motion starts after calibration");
    expect_true(result.motion_delta > 0.15F, "motion delta should increase when gyro changes");
}

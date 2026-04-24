// rest/MVC 샘플 누적 결과가 안정적인 기준값으로 계산되는지 검증한다.
#include "calibration.h"
#include "config.h"
#include "test_utils.h"

void run_test_calibration() {
    mvp::CalibrationManager calibration;
    calibration.reset();
    calibration.begin_rest_capture();

    for (std::size_t sample = 0; sample < mvp::kCalibrationSampleCount; ++sample) {
        calibration.push_rest_sample({0.2F, 0.25F, 0.3F});
    }

    expect_true(calibration.rest_complete(), "rest calibration should complete");
    expect_near(
        calibration.profile().rest_baseline[1],
        0.25F,
        0.001F,
        "rest baseline should be averaged"
    );

    calibration.begin_mvc_capture();
    for (std::size_t sample = 0; sample < mvp::kCalibrationSampleCount; ++sample) {
        float channel0 = 0.35F;
        if (sample < 8) {
            channel0 = 1.10F - (0.10F * static_cast<float>(sample));
        }

        calibration.push_mvc_sample({channel0, 0.26F, 1.1F});
    }

    expect_true(calibration.mvc_complete(), "mvc calibration should complete");
    expect_true(calibration.profile().mvc_ready, "mvc flag should be set");
    expect_near(
        calibration.profile().mvc_peak[0],
        1.1F,
        0.001F,
        "mvc peak should retain the maximum value"
    );
    expect_near(
        calibration.profile().mvc_reference[0],
        0.75F,
        0.001F,
        "mvc reference should use the average of top sustained samples"
    );
    expect_near(
        calibration.profile().mvc_peak[1],
        0.30F,
        0.001F,
        "mvc peak should not fall below rest baseline plus minimum margin"
    );
    expect_near(
        calibration.profile().mvc_reference[1],
        0.30F,
        0.001F,
        "mvc reference should clamp to minimum margin when contraction is too small"
    );
    expect_near(
        calibration.profile().mvc_peak[2],
        1.1F,
        0.001F,
        "mvc peak should retain the maximum value"
    );
    expect_near(
        calibration.profile().mvc_reference[2],
        1.1F,
        0.001F,
        "flat mvc samples should preserve their sustained reference"
    );
}

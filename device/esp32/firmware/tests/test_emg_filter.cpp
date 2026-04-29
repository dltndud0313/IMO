// 실제 센서 튜닝 전에 EMG 수학 유틸(RMS/이동평균/표시 smoothing) 정확도를 확인한다.
#include <array>
#include <deque>

#include "emg_filter.h"
#include "test_utils.h"

void run_test_emg_filter() {
    const std::deque<float> samples {1.0F, 2.0F, 3.0F, 4.0F};
    expect_near(
        mvp::compute_moving_average(samples, 4),
        2.5F,
        0.001F,
        "moving average should match expected value"
    );
    expect_near(
        mvp::compute_rms(samples, 4),
        2.7386F,
        0.001F,
        "RMS should match expected value"
    );
    expect_near(
        mvp::smooth_display(1.0F, 0.0F, 0.18F, 0.05F),
        0.18F,
        0.001F,
        "display smoothing should rise with attack alpha"
    );
    expect_near(
        mvp::smooth_display(0.0F, 1.0F, 0.18F, 0.05F),
        0.95F,
        0.001F,
        "display smoothing should decay with release alpha"
    );
    expect_true(
        mvp::threshold_active(0.21F, false, 0.20F, 0.12F),
        "threshold check should activate above on-threshold"
    );
    expect_true(
        !mvp::threshold_active(0.11F, true, 0.20F, 0.12F),
        "threshold check should deactivate below off-threshold"
    );

    mvp::EmgFilter detach_filter;
    mvp::EmgProcessingResult detach_result =
        detach_filter.process({1.0F, 0.0F, 0.0F, 0.0F});
    expect_near(
        detach_result.display[0],
        1.0F,
        0.001F,
        "detached EMG should display max warning value"
    );
    detach_result = detach_filter.process({0.0F, 0.0F, 0.0F, 0.0F});
    expect_near(
        detach_result.display[0],
        0.0F,
        0.001F,
        "reattached EMG should restart from zero without poisoned history"
    );

    mvp::EmgFilter low_force_filter;
    mvp::EmgProcessingResult low_force_result;
    for (int sample = 0; sample < 20; ++sample) {
        low_force_filter.process({0.0F, 0.0F, 0.0F, 0.0F});
    }
    for (int sample = 0; sample < 80; ++sample) {
        low_force_result = low_force_filter.process({0.02F, 0.0F, 0.0F, 0.0F});
    }
    expect_true(
        low_force_result.display[0] > 0.08F,
        "low sustained EMG should keep a visible display value"
    );

    mvp::EmgFilter steady_filter;
    mvp::EmgProcessingResult steady_result;
    for (int sample = 0; sample < 80; ++sample) {
        steady_result = steady_filter.process({0.02F, 0.0F, 0.0F, 0.0F});
    }
    const float steady_before_dip = steady_result.display[0];
    for (int sample = 0; sample < 10; ++sample) {
        steady_result = steady_filter.process({0.015F, 0.0F, 0.0F, 0.0F});
    }
    expect_true(
        steady_result.display[0] > steady_before_dip * 0.75F,
        "small sustained-force dips should not collapse the displayed EMG value"
    );

    mvp::EmgFilter filter;
    mvp::EmgProcessingResult result;
    for (int sample = 0; sample < 16; ++sample) {
        result = filter.process({0.8F, 0.4F, 0.2F, 0.1F});
    }

    expect_true(result.rms[0] > 0.75F, "rms should follow sustained contraction level");
    expect_true(
        result.display[0] > 0.70F && result.display[0] <= 0.90F,
        "display value should rise for sustained contraction"
    );
    expect_true(result.active[0], "filter should report active after sustained contraction");

    for (int sample = 0; sample < 40; ++sample) {
        result = filter.process({0.0F, 0.0F, 0.0F, 0.0F});
    }

    expect_true(
        result.display[0] < 0.70F,
        "display value should decay gradually after relaxation"
    );
    for (int sample = 0; sample < 120; ++sample) {
        result = filter.process({0.0F, 0.0F, 0.0F, 0.0F});
    }

    expect_true(!result.active[0], "filter should deactivate after enough relaxed samples");
}

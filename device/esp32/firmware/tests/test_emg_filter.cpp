// 실제 센서 튜닝 전에 EMG 수학 유틸(RMS/이동평균/정규화) 정확도를 확인한다.
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
        mvp::apply_baseline(0.7F, 0.2F),
        0.5F,
        0.001F,
        "baseline correction should subtract baseline"
    );
    expect_near(
        mvp::normalize_activation(0.6F, 0.2F, 1.0F),
        0.5F,
        0.001F,
        "normalization should map into 0..1"
    );
    expect_near(
        mvp::smooth_activation(1.0F, 0.0F, 0.35F, 0.08F),
        0.35F,
        0.001F,
        "attack smoothing should rise quickly"
    );
    expect_near(
        mvp::smooth_activation(0.0F, 1.0F, 0.35F, 0.08F),
        0.92F,
        0.001F,
        "release smoothing should fall slowly"
    );
    expect_true(
        mvp::threshold_active(0.21F, false, 0.20F, 0.12F),
        "threshold check should activate above on-threshold"
    );
    expect_true(
        !mvp::threshold_active(0.19F, false, 0.20F, 0.12F),
        "threshold check should stay inactive below on-threshold"
    );
    expect_true(
        mvp::threshold_active(0.13F, true, 0.20F, 0.12F),
        "hysteresis should keep active state until off-threshold is crossed"
    );
    expect_true(
        !mvp::threshold_active(0.11F, true, 0.20F, 0.12F),
        "threshold check should deactivate below off-threshold"
    );

    mvp::CalibrationProfile profile;
    profile.rest_baseline = {0.0F, 0.0F, 0.0F};
    profile.mvc_peak = {1.0F, 1.0F, 1.0F};
    profile.mvc_reference = {1.0F, 1.0F, 1.0F};
    profile.rest_ready = true;
    profile.mvc_ready = true;

    mvp::EmgFilter filter;
    mvp::EmgProcessingResult result;
    for (int sample = 0; sample < 6; ++sample) {
        result = filter.process({0.8F, 0.0F, 0.0F}, profile);
    }

    expect_near(
        result.normalized_instant[0],
        0.8F,
        0.001F,
        "normalized instant should follow sustained contraction level"
    );
    expect_true(
        result.normalized[0] > 0.70F,
        "smoothed activation should rise toward the sustained contraction level"
    );
    expect_true(
        result.normalized_display[0] > 0.35F && result.normalized_display[0] < result.normalized[0],
        "display smoothing should rise more slowly than logic smoothing"
    );
    expect_true(result.active[0], "filter should report active after sustained contraction");

    for (int sample = 0; sample < 64; ++sample) {
        result = filter.process({0.0F, 0.0F, 0.0F}, profile);
    }

    expect_true(
        result.normalized[0] < 0.12F,
        "smoothed activation should decay after relaxation"
    );
    expect_true(
        result.normalized_display[0] > result.normalized[0],
        "display smoothing should decay more slowly for a steadier UI value"
    );
    expect_true(!result.active[0], "filter should deactivate after enough relaxed samples");
}

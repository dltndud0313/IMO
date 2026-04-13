// 실제 센서 튜닝 전에 EMG 수학 유틸(RMS/이동평균/정규화) 정확도를 확인한다.
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
    expect_true(
        mvp::threshold_active(0.5F, 0.35F),
        "threshold check should activate above threshold"
    );
}

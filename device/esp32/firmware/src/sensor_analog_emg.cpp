// SZH-GJD001 예제의 500Hz band-pass 아이디어를 현재 파이프라인에 맞게 옮긴 단일채널 EMG 어댑터 구현.
#include "sensor_analog_emg.h"

#include <algorithm>
#include <cmath>
#include <utility>

namespace mvp {
namespace {

float process_section(
    float input,
    float* z1,
    float* z2,
    float a1,
    float a2,
    float b0,
    float b1,
    float b2
) {
    // IIR biquad 한 섹션의 내부 상태를 갱신한다. 판매처 예제의 z1/z2 구조를 그대로 옮긴 것이다.
    const float x = input - (a1 * (*z1)) - (a2 * (*z2));
    const float output = (b0 * x) + (b1 * (*z1)) + (b2 * (*z2));
    *z2 = *z1;
    *z1 = x;
    return output;
}

}  // namespace

float ButterworthBandPassFilter::process(float input) {
    float output = input;
    // 판매처 제공 예제의 계수를 그대로 이어 붙여 4개 섹션 band-pass를 구성한다.
    output = process_section(output, &z1_1_, &z1_2_, -0.73945727F, 0.59923508F, 0.00223489F, 0.00446978F, 0.00223489F);
    output = process_section(output, &z2_1_, &z2_2_, -1.03789224F, 0.64082390F, 1.00000000F, 2.00000000F, 1.00000000F);
    output = process_section(output, &z3_1_, &z3_2_, -0.59186255F, 0.80647974F, 1.00000000F, -2.00000000F, 1.00000000F);
    output = process_section(output, &z4_1_, &z4_2_, -1.33318587F, 0.85392964F, 1.00000000F, -2.00000000F, 1.00000000F);
    return output;
}

void ButterworthBandPassFilter::reset() {
    z1_1_ = 0.0F;
    z1_2_ = 0.0F;
    z2_1_ = 0.0F;
    z2_2_ = 0.0F;
    z3_1_ = 0.0F;
    z3_2_ = 0.0F;
    z4_1_ = 0.0F;
    z4_2_ = 0.0F;
}

AnalogEmgSensorSource::AnalogEmgSensorSource(RawSampleReader raw_reader, AnalogEmgSensorConfig config)
    : raw_reader_(std::move(raw_reader)), config_(config) {}

SensorFrame AnalogEmgSensorSource::read_frame(uint32_t timestamp_ms) {
    SensorFrame frame;
    frame.emg.timestamp_ms = timestamp_ms;

    // 프레임당 여러 raw 샘플을 읽어 절대값 평균으로 묶어주면 단일 ADC 샘플보다 안정적으로 들어온다.
    const std::size_t samples_to_read = std::max<std::size_t>(config_.samples_per_frame, 1U);
    float envelope_sum = 0.0F;

    for (std::size_t index = 0; index < samples_to_read; ++index) {
        const float raw_sample = read_raw_sample();
        // ADC 값을 0~1 범위로 정규화한 뒤 중심점을 0 근처로 옮겨 band-pass 입력으로 사용한다.
        const float centered = (raw_sample / config_.adc_full_scale) - 0.5F;
        const float filtered = band_pass_filter_.process(centered);
        // 정류(rectify) 후 평균을 내서 채널 활성도처럼 쓰기 쉬운 envelope를 만든다.
        envelope_sum += std::fabs(filtered);
    }

    frame.emg.channels = {
        envelope_sum / static_cast<float>(samples_to_read),
        // 현재 검토 중인 센서는 단일채널 전제로 두고 있으므로 나머지 채널은 0으로 둔다.
        0.0F,
        0.0F,
    };
    // IMU는 아직 연결 전이므로 bring-up 이전에는 0으로 유지한다.
    frame.imu.accel = {0.0F, 0.0F, 0.0F};
    frame.imu.gyro = {0.0F, 0.0F, 0.0F};
    return frame;
}

void AnalogEmgSensorSource::reset() {
    band_pass_filter_.reset();
}

float AnalogEmgSensorSource::read_raw_sample() const {
    if (raw_reader_) {
        // 호스트 테스트나 샘플 주입 시에는 외부 콜백 값을 그대로 사용한다.
        return raw_reader_();
    }

    // 실제 장착 후 이 자리에 ESP-IDF adc_oneshot_read 연동을 넣으면 된다.
    return 0.0F;
}

}  // namespace mvp

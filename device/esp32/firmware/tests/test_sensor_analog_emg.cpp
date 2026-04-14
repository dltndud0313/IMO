// 단일 아날로그 EMG 어댑터가 한 프레임 내에서 샘플을 모아 channel 1로 내보내는지 확인한다.
#include <cmath>
#include <vector>

#include "sensor_analog_emg.h"
#include "test_utils.h"

void run_test_sensor_analog_emg() {
    std::size_t index = 0;
    std::vector<float> samples;
    samples.reserve(20);
    for (int step = 0; step < 20; ++step) {
        const float wave = std::sin(static_cast<float>(step) * 0.7F);
        samples.push_back(2048.0F + (wave * 900.0F));
    }

    mvp::AnalogEmgSensorConfig config;
    config.samples_per_frame = 10;
    config.adc_full_scale = 4095.0F;

    mvp::AnalogEmgSensorSource sensor(
        [&samples, &index]() {
            const float value = samples[index % samples.size()];
            ++index;
            return value;
        },
        config
    );

    const auto frame = sensor.read_frame(0);
    expect_true(frame.emg.channels[0] > 0.0F, "analog EMG adapter should emit a positive envelope on channel 1");
    expect_near(frame.emg.channels[1], 0.0F, 0.0001F, "single-channel adapter should keep channel 2 at zero");
    expect_near(frame.emg.channels[2], 0.0F, 0.0001F, "single-channel adapter should keep channel 3 at zero");
}

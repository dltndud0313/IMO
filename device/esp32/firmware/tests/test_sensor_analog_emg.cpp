// 단일 아날로그 EMG 어댑터가 한 프레임 내에서 샘플을 모아 channel 1로 내보내는지 확인한다.
#include <cmath>
#include <vector>

#include "sensor_analog_emg.h"
#include "test_utils.h"

void run_test_sensor_analog_emg() {
    std::size_t index = 0;
    std::vector<float> samples;
    samples.reserve(140);
    for (int step = 0; step < 100; ++step) {
        samples.push_back(2048.0F);
    }
    for (int step = 0; step < 40; ++step) {
        samples.push_back(2448.0F);
    }

    mvp::AnalogEmgSensorConfig config;
    config.samples_per_frame = 10;
    config.adc_full_scale = 4095.0F;
    config.emg_channel_enabled = {true, false, false, false};

    mvp::AnalogEmgSensorSource sensor(
        [&samples, &index]() {
            const float value = samples[index % samples.size()];
            ++index;
            return value;
        },
        config
    );

    mvp::SensorFrame frame;
    for (int frame_index = 0; frame_index < 10; ++frame_index) {
        frame = sensor.read_frame(static_cast<uint32_t>(frame_index * 20));
        expect_near(frame.emg.channels[0], 0.0F, 0.0001F, "analog EMG baseline warmup should emit zero");
    }
    frame = sensor.read_frame(200);
    expect_true(frame.emg.channels[0] > 0.0F, "analog EMG adapter should emit a positive envelope on channel 1");
    const float held_value = frame.emg.channels[0];
    for (int frame_index = 11; frame_index < 14; ++frame_index) {
        frame = sensor.read_frame(static_cast<uint32_t>(frame_index * 20));
    }
    expect_near(frame.emg.channels[0], held_value, 0.001F, "analog EMG should hold steady for steady raw force");
    expect_near(frame.emg.channels[1], 0.0F, 0.0001F, "disabled EMG channel 2 should stay zero");
    expect_near(frame.emg.channels[2], 0.0F, 0.0001F, "disabled EMG channel 3 should stay zero");
    expect_near(frame.emg.channels[3], 0.0F, 0.0001F, "disabled EMG channel 4 should stay zero");

    std::size_t noisy_index = 0;
    std::vector<float> noisy_samples;
    noisy_samples.reserve(160);
    for (int step = 0; step < 120; ++step) {
        noisy_samples.push_back(2048.0F + (step % 2 == 0 ? 35.0F : -35.0F));
    }
    for (int step = 0; step < 20; ++step) {
        noisy_samples.push_back(2048.0F + (step % 2 == 0 ? 30.0F : -30.0F));
    }
    for (int step = 0; step < 20; ++step) {
        noisy_samples.push_back(2448.0F);
    }

    mvp::AnalogEmgSensorSource noisy_sensor(
        [&noisy_samples, &noisy_index]() {
            const float value = noisy_samples[noisy_index % noisy_samples.size()];
            ++noisy_index;
            return value;
        },
        config
    );
    for (int frame_index = 0; frame_index < 12; ++frame_index) {
        frame = noisy_sensor.read_frame(static_cast<uint32_t>(frame_index * 20));
    }
    frame = noisy_sensor.read_frame(240);
    expect_near(
        frame.emg.channels[0],
        0.0F,
        0.0001F,
        "analog EMG should suppress measured rest noise after baseline warmup"
    );
    noisy_sensor.read_frame(260);
    frame = noisy_sensor.read_frame(280);
    expect_true(
        frame.emg.channels[0] > 0.0F,
        "analog EMG should still react above the measured rest noise"
    );
}

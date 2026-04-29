// ESP-IDF 진입점. 초기 단계에서는 mock 파이프라인을 연속 실행해 디바이스 루프를 먼저 검증한다.
#include <algorithm>
#include <array>
#include <cstdio>

#include "config.h"
#include "runtime_pipeline.h"
#include "sensor_analog_emg.h"
#include "transport_serial.h"

#if __has_include("freertos/FreeRTOS.h")
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#endif

extern "C" void app_main(void) {
    mvp::AnalogEmgSensorConfig sensor_config;
    sensor_config.source_sample_rate_hz = mvp::kAnalogEmgRecommendedSampleRateHz;
    sensor_config.samples_per_frame = mvp::kAnalogEmgSamplesPerFrame;
    sensor_config.adc_full_scale = mvp::kAnalogEmgAdcFullScale;
    sensor_config.emg_adc_gpios = mvp::kAnalogEmgAdcGpios;
    sensor_config.emg_channel_enabled = mvp::kAnalogEmgChannelEnabled;
    sensor_config.imu_i2c_port = mvp::kImuI2cPort;
    sensor_config.imu_sda_gpio = mvp::kImuI2cSdaGpio;
    sensor_config.imu_scl_gpio = mvp::kImuI2cSclGpio;
    sensor_config.imu_i2c_clock_hz = mvp::kImuI2cClockHz;
    sensor_config.imu_i2c_transaction_timeout_ms = mvp::kImuI2cTransactionTimeoutMs;
    sensor_config.imu_addresses = mvp::kMpu6050Addresses;
    sensor_config.imu_sensor_enabled = mvp::kImuSensorEnabled;

    mvp::AnalogEmgSensorSource sensor_source({}, sensor_config);

    if (mvp::kEnableEmgRawSerialPlotterMode) {
        std::array<float, mvp::kEmgRawSerialPlotterWindowSamples> recent_raw_emg {};
        std::size_t recent_count = 0;
        std::size_t recent_index = 0;

        while (true) {
            const float raw_emg = sensor_source.read_debug_raw_emg_sample();
            recent_raw_emg[recent_index] = raw_emg;
            recent_index = (recent_index + 1U) % recent_raw_emg.size();
            if (recent_count < recent_raw_emg.size()) {
                ++recent_count;
            }

            float min_raw = raw_emg;
            float max_raw = raw_emg;
            for (std::size_t index = 0; index < recent_count; ++index) {
                min_raw = std::min(min_raw, recent_raw_emg[index]);
                max_raw = std::max(max_raw, recent_raw_emg[index]);
            }

            // Serial Plotter에서 raw / 최근 최소 / 최근 최대를 한 번에 비교할 수 있게 세 값을 같이 출력한다.
            printf(
                "raw:%.0f,min:%.0f,max:%.0f\n",
                static_cast<double>(raw_emg),
                static_cast<double>(min_raw),
                static_cast<double>(max_raw)
            );

#if __has_include("freertos/FreeRTOS.h")
            vTaskDelay(pdMS_TO_TICKS(mvp::kEmgRawSerialPlotterIntervalMs));
#endif
        }
    }

    // 현재는 실제 IMU 값을 우선 읽고, EMG ADC는 연결된 ADC 입력을 통해 읽는다.
    mvp::SerialTransport transport(mvp::kDefaultPacketFormat);
    mvp::MockRuntimePipeline pipeline(sensor_source, transport);

    uint32_t timestamp_ms = 0;
    while (true) {
        pipeline.tick(timestamp_ms);
        timestamp_ms += mvp::kSampleIntervalMs;

#if __has_include("freertos/FreeRTOS.h")
        vTaskDelay(pdMS_TO_TICKS(mvp::kSampleIntervalMs));
#endif
    }
}

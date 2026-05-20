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
    sensor_config.imu_i2c_ports = mvp::kImuI2cPorts;
    sensor_config.imu_sda_gpios = mvp::kImuI2cSdaGpios;
    sensor_config.imu_scl_gpios = mvp::kImuI2cSclGpios;
    sensor_config.imu_i2c_clock_hz = mvp::kImuI2cClockHz;
    sensor_config.imu_i2c_transaction_timeout_ms = mvp::kImuI2cTransactionTimeoutMs;
    sensor_config.imu_addresses = mvp::kMpu6050Addresses;
    sensor_config.imu_sensor_enabled = mvp::kImuSensorEnabled;

    mvp::AnalogEmgSensorSource sensor_source({}, sensor_config);

    if (mvp::kEnableEmgRawSerialPlotterMode) {
        while (true) {
            const std::array<float, mvp::kEmgChannelCount> raw_emg =
                sensor_source.read_debug_raw_emg_samples();

            // EMG 배선/센서 진단용 모드다. 이 모드에서는 BINARY_V2 패킷을 보내지 않는다.
            printf(
                "raw1:%.0f,raw2:%.0f,raw3:%.0f,raw4:%.0f\n",
                static_cast<double>(raw_emg[0]),
                static_cast<double>(raw_emg[1]),
                static_cast<double>(raw_emg[2]),
                static_cast<double>(raw_emg[3])
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

// ESP-IDF 진입점. 초기 단계에서는 mock 파이프라인을 연속 실행해 디바이스 루프를 먼저 검증한다.
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
    sensor_config.imu_i2c_port = mvp::kImuI2cPort;
    sensor_config.imu_sda_gpio = mvp::kImuI2cSdaGpio;
    sensor_config.imu_scl_gpio = mvp::kImuI2cSclGpio;
    sensor_config.imu_i2c_clock_hz = mvp::kImuI2cClockHz;
    sensor_config.imu_address = mvp::kMpu6050Address;

    // 현재는 실제 IMU 값을 우선 읽고, EMG ADC는 아직 미연동이면 0으로 유지한다.
    mvp::AnalogEmgSensorSource sensor_source({}, sensor_config);
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

// ESP-IDF 진입점. 초기 단계에서는 mock 파이프라인을 연속 실행해 디바이스 루프를 먼저 검증한다.
#include "config.h"
#include "runtime_pipeline.h"
#include "sensor_mock.h"
#include "transport_serial.h"

#if __has_include("freertos/FreeRTOS.h")
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#endif

extern "C" void app_main(void) {
    mvp::MockSensorSource sensor_source;
    mvp::SerialTransport transport;
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

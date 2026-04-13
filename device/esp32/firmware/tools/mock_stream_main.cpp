// ESP-IDF 없이 ESP32 출력 형태를 흉내 내는 host-side mock emitter.
#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <string>

#include "config.h"
#include "runtime_pipeline.h"
#include "sensor_mock.h"
#include "transport_serial.h"

namespace {

int parse_count(int argc, char** argv) {
    if (argc >= 2) {
        return std::max(1, std::atoi(argv[1]));
    }
    return 120;
}

}  // namespace

int main(int argc, char** argv) {
    const int count = parse_count(argc, argv);
    mvp::MockSensorSource sensor_source;
    mvp::SerialTransport transport;
    mvp::MockRuntimePipeline pipeline(sensor_source, transport);

    uint32_t timestamp_ms = 0;
    for (int index = 0; index < count; ++index) {
        pipeline.tick(timestamp_ms);
        timestamp_ms += mvp::kSampleIntervalMs;
    }

    return 0;
}

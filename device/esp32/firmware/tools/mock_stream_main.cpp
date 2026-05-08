// ESP-IDF 없이 ESP32 출력 형태를 흉내 내는 host-side mock emitter.
#include <algorithm>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <string>

#include "config.h"
#include "runtime_pipeline.h"
#include "sensor_mock.h"
#include "transport_serial.h"

namespace {

struct Options {
    mvp::MockWorkoutProfile profile {mvp::MockWorkoutProfile::DEFAULT};
    mvp::PacketFormat format {mvp::PacketFormat::BINARY_V2};
    int frame_count {120};
    int reps {0};
    bool loop {false};
    float speed {1.0F};
    float intensity {1.0F};
};

void print_usage(const char* argv0) {
    std::cerr
        << "usage: " << argv0
        << " [--exercise default|curl|pushup|squat|raise]"
        << " [--reps N] [--frames N] [--loop]"
        << " [--speed FLOAT] [--intensity FLOAT]"
        << " [--format binary|json]\n";
}

mvp::MockWorkoutProfile parse_profile_name(const std::string& profile) {
    if (profile == "curl" || profile == "bicep_curl") {
        return mvp::MockWorkoutProfile::BICEP_CURL;
    }
    if (profile == "pushup" || profile == "push_up") {
        return mvp::MockWorkoutProfile::PUSH_UP;
    }
    if (profile == "squat") {
        return mvp::MockWorkoutProfile::SQUAT;
    }
    if (profile == "raise" || profile == "lateral_raise") {
        return mvp::MockWorkoutProfile::LATERAL_RAISE;
    }
    return mvp::MockWorkoutProfile::DEFAULT;
}

mvp::PacketFormat parse_format_name(const std::string& format) {
    if (format == "json" || format == "json_v1") {
        return mvp::PacketFormat::JSON_V1;
    }
    return mvp::PacketFormat::BINARY_V2;
}

uint32_t base_period_ms(mvp::MockWorkoutProfile profile) {
    switch (profile) {
        case mvp::MockWorkoutProfile::BICEP_CURL:
            return 3200U;
        case mvp::MockWorkoutProfile::PUSH_UP:
            return 2800U;
        case mvp::MockWorkoutProfile::SQUAT:
            return 3000U;
        case mvp::MockWorkoutProfile::LATERAL_RAISE:
            return 3200U;
        case mvp::MockWorkoutProfile::DEFAULT:
        default:
            return 4000U;
    }
}

int frames_per_rep(const Options& options) {
    const float speed = std::max(options.speed, 0.1F);
    const float scaled_period = std::max(
        400.0F,
        static_cast<float>(base_period_ms(options.profile)) / speed
    );
    return std::max(
        1,
        static_cast<int>(scaled_period / static_cast<float>(mvp::kSampleIntervalMs))
    );
}

Options parse_options(int argc, char** argv) {
    Options options;

    for (int index = 1; index < argc; ++index) {
        const std::string arg = argv[index];
        if (arg == "--exercise" && index + 1 < argc) {
            options.profile = parse_profile_name(argv[++index]);
            continue;
        }
        if (arg == "--reps" && index + 1 < argc) {
            options.reps = std::max(0, std::atoi(argv[++index]));
            continue;
        }
        if (arg == "--frames" && index + 1 < argc) {
            options.frame_count = std::max(1, std::atoi(argv[++index]));
            continue;
        }
        if (arg == "--loop") {
            options.loop = true;
            continue;
        }
        if (arg == "--speed" && index + 1 < argc) {
            options.speed = std::max(0.1F, std::strtof(argv[++index], nullptr));
            continue;
        }
        if (arg == "--intensity" && index + 1 < argc) {
            options.intensity = std::max(0.1F, std::strtof(argv[++index], nullptr));
            continue;
        }
        if (arg == "--format" && index + 1 < argc) {
            options.format = parse_format_name(argv[++index]);
            continue;
        }
        if (arg == "--help" || arg == "-h") {
            print_usage(argv[0]);
            std::exit(0);
        }
    }

    if (options.reps > 0 && !options.loop) {
        options.frame_count = std::max(1, options.reps * frames_per_rep(options));
    }

    return options;
}

}  // namespace

int main(int argc, char** argv) {
    const Options options = parse_options(argc, argv);
    mvp::MockSensorConfig sensor_config;
    sensor_config.profile = options.profile;
    sensor_config.intensity = options.intensity;
    sensor_config.speed = options.speed;

    mvp::MockSensorSource sensor_source(sensor_config);
    mvp::SerialTransport transport(options.format);
    mvp::MockRuntimePipeline pipeline(sensor_source, transport);

    uint32_t timestamp_ms = 0;
    if (options.loop) {
        while (true) {
            pipeline.tick(timestamp_ms);
            timestamp_ms += mvp::kSampleIntervalMs;
        }
    }

    for (int index = 0; index < options.frame_count; ++index) {
        pipeline.tick(timestamp_ms);
        timestamp_ms += mvp::kSampleIntervalMs;
    }

    return 0;
}

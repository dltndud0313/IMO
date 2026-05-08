// Grove EMG/MPU-6050 도착 전 파이프라인 검증용 가짜 EMG/IMU 소스 선언.
#pragma once

#include "sensor_source.h"

namespace mvp {

enum class MockWorkoutProfile {
    DEFAULT = 0,
    BICEP_CURL,
    PUSH_UP,
    SQUAT,
    LATERAL_RAISE,
};

struct MockSensorConfig {
    MockWorkoutProfile profile {MockWorkoutProfile::DEFAULT};
    float intensity {1.0F};
    float speed {1.0F};
};

class MockSensorSource : public ISensorSource {
  public:
    explicit MockSensorSource(MockWorkoutProfile profile = MockWorkoutProfile::DEFAULT)
        : config_({profile, 1.0F, 1.0F}) {}
    explicit MockSensorSource(MockSensorConfig config)
        : config_(config) {}

    bool is_mock() const override { return true; }
    std::size_t imu_ready_count() const override { return kImuSensorCount; }
    SensorFrame read_frame(uint32_t timestamp_ms) override;

  private:
    MockSensorConfig config_ {};
};

}  // namespace mvp

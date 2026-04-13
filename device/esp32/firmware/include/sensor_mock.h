// Grove EMG/MPU-6050 도착 전 파이프라인 검증용 가짜 EMG/IMU 소스 선언.
#pragma once

#include "sensor_source.h"

namespace mvp {

class MockSensorSource : public ISensorSource {
  public:
    SensorFrame read_frame(uint32_t timestamp_ms) override;
};

}  // namespace mvp

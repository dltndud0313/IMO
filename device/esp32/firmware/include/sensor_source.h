// 하드웨어 추상화 경계. 실제 센서와 mock 센서가 같은 read_frame 계약을 구현한다.
#pragma once

#include <cstddef>
#include <cstdint>

#include "types.h"

namespace mvp {

class ISensorSource {
  public:
    virtual ~ISensorSource() = default;
    virtual bool is_mock() const { return false; }
    virtual std::size_t imu_ready_count() const { return 0; }
    virtual std::size_t imu_expected_count() const { return kImuSensorCount; }
    virtual SensorFrame read_frame(uint32_t timestamp_ms) = 0;
};

}  // namespace mvp

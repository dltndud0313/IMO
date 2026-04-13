// 펌웨어 전체 흐름(sense -> process -> calibrate -> packet -> transport)을 묶는 오케스트레이터.
#pragma once

#include "calibration.h"
#include "emg_filter.h"
#include "imu_processor.h"
#include "sensor_source.h"
#include "state_machine.h"
#include "transport_serial.h"

namespace mvp {

struct PipelineTickResult {
    OutputPacket packet {};
    EmgProcessingResult emg {};
    ImuProcessingResult imu {};
    RuntimeState state {RuntimeState::IDLE};
};

class MockRuntimePipeline {
  public:
    MockRuntimePipeline(ISensorSource& sensor_source, SerialTransport& transport);

    PipelineTickResult tick(uint32_t timestamp_ms);
    void reset();

  private:
    OutputPacket build_packet(
        uint32_t timestamp_ms,
        const EmgProcessingResult& emg,
        const ImuProcessingResult& imu,
        RuntimeState state
    );

    ISensorSource& sensor_source_;
    SerialTransport& transport_;
    EmgFilter emg_filter_ {};
    ImuProcessor imu_processor_ {};
    CalibrationManager calibration_ {};
    StateMachine state_machine_ {};
    uint32_t sequence_ {0};
};

}  // namespace mvp

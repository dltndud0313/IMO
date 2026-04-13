// 모듈을 조립해 한 tick의 실행 흐름을 완성하는 핵심 파일.
#include "runtime_pipeline.h"

#include "config.h"

namespace mvp {

MockRuntimePipeline::MockRuntimePipeline(ISensorSource& sensor_source, SerialTransport& transport)
    : sensor_source_(sensor_source), transport_(transport) {
    calibration_.reset();
    state_machine_.reset();
}

PipelineTickResult MockRuntimePipeline::tick(uint32_t timestamp_ms) {
    // 하드웨어 없이도 전체 상태 흐름을 검증하려고 mock 실행 시 캘리브레이션을 자동 시작한다.
    if (state_machine_.state() == RuntimeState::IDLE) {
        calibration_.begin_rest_capture();
        state_machine_.handle_event(RuntimeEvent::BEGIN_REST_CALIBRATION);
    }

    const SensorFrame frame = sensor_source_.read_frame(timestamp_ms);
    const EmgProcessingResult emg_result =
        emg_filter_.process(frame.emg.channels, calibration_.profile());
    const ImuProcessingResult imu_result = imu_processor_.process(frame.imu);

    if (state_machine_.state() == RuntimeState::CALIBRATION_REST) {
        calibration_.push_rest_sample(emg_result.rms);
        if (calibration_.rest_complete()) {
            calibration_.begin_mvc_capture();
            state_machine_.handle_event(RuntimeEvent::COMPLETE_REST_CALIBRATION);
        }
    } else if (state_machine_.state() == RuntimeState::CALIBRATION_MVC) {
        calibration_.push_mvc_sample(emg_result.rms);
        if (calibration_.mvc_complete()) {
            state_machine_.handle_event(RuntimeEvent::COMPLETE_MVC_CALIBRATION);
        }
    } else if (state_machine_.state() == RuntimeState::READY) {
        state_machine_.handle_event(RuntimeEvent::ARM_STREAMING);
    }

    // 캘리브레이션 중에도 패킷을 계속 송신해 Pi에서 전체 수명주기를 관측할 수 있게 한다.
    const RuntimeState state = state_machine_.state();
    const OutputPacket packet = build_packet(timestamp_ms, emg_result, imu_result, state);
    transport_.send_packet(packet);

    return {
        packet,
        emg_result,
        imu_result,
        state,
    };
}

void MockRuntimePipeline::reset() {
    sequence_ = 0;
    calibration_.reset();
    state_machine_.reset();
    emg_filter_.reset();
    imu_processor_.reset();
}

OutputPacket MockRuntimePipeline::build_packet(
    uint32_t timestamp_ms,
    const EmgProcessingResult& emg,
    const ImuProcessingResult& imu,
    RuntimeState state
) {
    uint32_t flags = kFlagMockData;
    if (calibration_.profile().rest_ready && calibration_.profile().mvc_ready) {
        flags |= kFlagCalibrationReady;
    }
    if (imu.motion_delta >= kMotionDetectionThreshold) {
        flags |= kFlagMotionDetected;
    }

    OutputPacket packet;
    packet.schema = kPacketSchema;
    packet.seq = sequence_;
    packet.timestamp_ms = timestamp_ms;
    packet.emg_ch1 = emg.normalized[0];
    packet.emg_ch2 = emg.normalized[1];
    packet.emg_ch3 = emg.normalized[2];
    packet.acc_x = imu.accel_smoothed[0];
    packet.acc_y = imu.accel_smoothed[1];
    packet.acc_z = imu.accel_smoothed[2];
    packet.gyro_x = imu.gyro_smoothed[0];
    packet.gyro_y = imu.gyro_smoothed[1];
    packet.gyro_z = imu.gyro_smoothed[2];
    packet.state = to_string(state);
    packet.flags = flags;

    ++sequence_;
    return packet;
}

}  // namespace mvp

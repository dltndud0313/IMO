// 모듈을 조립해 한 tick의 실행 흐름을 완성하는 핵심 파일.
#include "runtime_pipeline.h"

#include "config.h"

namespace mvp {

MockRuntimePipeline::MockRuntimePipeline(ISensorSource& sensor_source, SerialTransport& transport)
    : sensor_source_(sensor_source), transport_(transport) {
    state_machine_.reset();
}

PipelineTickResult MockRuntimePipeline::tick(uint32_t timestamp_ms) {
    const SensorFrame frame = sensor_source_.read_frame(timestamp_ms);
    const EmgProcessingResult emg_result = emg_filter_.process(frame.emg.channels);

    std::array<ImuProcessingResult, kImuSensorCount> imu_results {};
    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        imu_results[imu_index] = imu_processors_[imu_index].process(frame.imus[imu_index]);
    }

    const RuntimeState state = state_machine_.state();
    const OutputPacket packet = build_packet(timestamp_ms, emg_result, imu_results, state);
    transport_.send_packet(packet);

    return {
        packet,
        emg_result,
        imu_results,
        state,
    };
}

void MockRuntimePipeline::reset() {
    sequence_ = 0;
    state_machine_.reset();
    emg_filter_.reset();
    for (auto& imu_processor : imu_processors_) {
        imu_processor.reset();
    }
}

OutputPacket MockRuntimePipeline::build_packet(
    uint32_t timestamp_ms,
    const EmgProcessingResult& emg,
    const std::array<ImuProcessingResult, kImuSensorCount>& imus,
    RuntimeState state
) {
    uint32_t flags = 0;
    if (sensor_source_.is_mock()) {
        flags |= kFlagMockData;
    }

    std::size_t bias_ready_count = 0;
    bool motion_detected = false;
    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        if (imu_processors_[imu_index].gyro_bias_ready()) {
            ++bias_ready_count;
        }
        if (imus[imu_index].motion_delta >= kMotionDetectionThreshold) {
            motion_detected = true;
        }
    }

    const std::size_t source_imu_expected_count = sensor_source_.imu_expected_count();
    if (source_imu_expected_count > 0 && bias_ready_count >= source_imu_expected_count) {
        flags |= kFlagImuBiasReady;
    }
    if (source_imu_expected_count > 0 && bias_ready_count > 0 && bias_ready_count < source_imu_expected_count) {
        flags |= kFlagImuPartialReady;
    }
    if (motion_detected) {
        flags |= kFlagMotionDetected;
    }

    // 센서 소스의 초기화 결과(특히 다중 IMU 연결 상태)를 함께 노출한다.
    const std::size_t source_imu_ready_count = sensor_source_.imu_ready_count();
    if (
        source_imu_expected_count > 0 &&
        source_imu_ready_count > 0 &&
        source_imu_ready_count < source_imu_expected_count
    ) {
        flags |= kFlagImuPartialReady;
    }

    OutputPacket packet;
    packet.schema = kPacketSchemaJsonV1;
    packet.seq = sequence_;
    packet.timestamp_ms = timestamp_ms;
    packet.emg = emg.display;
    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        packet.imus[imu_index].accel = imus[imu_index].accel_smoothed;
        packet.imus[imu_index].gyro = imus[imu_index].gyro_smoothed;
    }
    packet.state = to_string(state);
    packet.flags = flags;

    ++sequence_;
    return packet;
}

}  // namespace mvp

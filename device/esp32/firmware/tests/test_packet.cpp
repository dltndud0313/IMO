// 패킷 인코딩/디코딩 후에도 Pi 수신기가 기대하는 필드가 보존되는지 확인한다.
#include "packet.h"
#include "test_utils.h"

void run_test_packet() {
    mvp::OutputPacket packet;
    packet.schema = "emg-glass.v1";
    packet.seq = 42;
    packet.timestamp_ms = 840;
    packet.emg_ch1 = 0.10F;
    packet.emg_ch2 = 0.30F;
    packet.emg_ch3 = 0.90F;
    packet.acc_x = 0.01F;
    packet.acc_y = 0.02F;
    packet.acc_z = 0.98F;
    packet.gyro_x = 0.15F;
    packet.gyro_y = 0.25F;
    packet.gyro_z = 0.35F;
    packet.state = "STREAMING";
    packet.flags = 7;
    packet.rep_index = 3;

    const std::string encoded = mvp::encode_packet(packet);
    mvp::OutputPacket decoded;
    expect_true(mvp::decode_packet(encoded, &decoded), "packet should decode successfully");
    expect_true(decoded.schema == packet.schema, "schema should round-trip");
    expect_true(decoded.seq == packet.seq, "seq should round-trip");
    expect_near(decoded.emg_ch3, packet.emg_ch3, 0.001F, "emg_ch3 should round-trip");
    expect_true(decoded.state == packet.state, "state should round-trip");
    expect_true(decoded.rep_index.has_value(), "rep_index should be preserved");
}

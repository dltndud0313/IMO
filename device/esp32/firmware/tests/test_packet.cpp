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
    packet.gyro_x = 45.15F;
    packet.gyro_y = -78.25F;
    packet.gyro_z = 123.35F;
    packet.state = "STREAMING";
    packet.flags = 7;
    packet.rep_index = 3;

    const mvp::PacketBuffer encoded_json = mvp::encode_packet(packet, mvp::PacketFormat::JSON_V1);
    mvp::OutputPacket decoded_json;
    expect_true(
        mvp::decode_packet(mvp::PacketFormat::JSON_V1, encoded_json, &decoded_json),
        "json packet should decode successfully"
    );
    expect_true(decoded_json.schema == packet.schema, "json schema should round-trip");
    expect_true(decoded_json.seq == packet.seq, "json seq should round-trip");
    expect_near(decoded_json.emg_ch3, packet.emg_ch3, 0.001F, "json emg_ch3 should round-trip");
    expect_true(decoded_json.state == packet.state, "json state should round-trip");
    expect_true(decoded_json.rep_index.has_value(), "json rep_index should be preserved");

    const mvp::PacketBuffer encoded_binary = mvp::encode_packet(packet, mvp::PacketFormat::BINARY_V2);
    expect_true(encoded_binary.size() == 38, "binary frame should have fixed 38-byte length");
    expect_true(encoded_binary.size() < encoded_json.size(), "binary frame should be smaller than json packet");
    mvp::OutputPacket decoded_binary;
    expect_true(
        mvp::decode_packet(mvp::PacketFormat::BINARY_V2, encoded_binary, &decoded_binary),
        "binary packet should decode successfully"
    );
    expect_true(decoded_binary.schema == "emg-glass.v2", "binary schema should decode as v2");
    expect_true(decoded_binary.seq == packet.seq, "binary seq should round-trip");
    expect_near(decoded_binary.emg_ch3, packet.emg_ch3, 0.001F, "binary emg_ch3 should round-trip");
    expect_near(decoded_binary.acc_z, packet.acc_z, 0.001F, "binary acc_z should round-trip");
    expect_near(decoded_binary.gyro_x, packet.gyro_x, 0.01F, "binary gyro_x should round-trip with gyro scale");
    expect_near(decoded_binary.gyro_y, packet.gyro_y, 0.01F, "binary gyro_y should round-trip with gyro scale");
    expect_near(decoded_binary.gyro_z, packet.gyro_z, 0.01F, "binary gyro_z should round-trip with gyro scale");
    expect_true(decoded_binary.state == packet.state, "binary state should round-trip");
    expect_true(decoded_binary.rep_index.has_value(), "binary rep_index should be preserved");
}

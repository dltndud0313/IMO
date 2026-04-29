// 패킷 인코딩/디코딩 후에도 Pi 수신기가 기대하는 필드가 보존되는지 확인한다.
#include "packet.h"
#include "test_utils.h"

void run_test_packet() {
    mvp::OutputPacket packet;
    packet.schema = "emg-glass.v2";
    packet.seq = 42;
    packet.timestamp_ms = 840;
    packet.emg = {0.10F, 0.30F, 0.90F, 0.25F};
    packet.imus[0].accel = {0.01F, 0.02F, 0.98F};
    packet.imus[0].gyro = {45.15F, -78.25F, 123.35F};
    packet.imus[1].accel = {-0.11F, 0.15F, 0.92F};
    packet.imus[1].gyro = {10.50F, 2.75F, -17.25F};
    packet.imus[2].accel = {0.22F, -0.06F, 1.04F};
    packet.imus[2].gyro = {-5.75F, 12.15F, 8.95F};
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
    expect_near(decoded_json.emg[3], packet.emg[3], 0.001F, "json emg_ch4 should round-trip");
    expect_near(decoded_json.imus[2].gyro[1], packet.imus[2].gyro[1], 0.001F, "json imu3 gyro y should round-trip");
    expect_true(decoded_json.state == packet.state, "json state should round-trip");
    expect_true(decoded_json.rep_index.has_value(), "json rep_index should be preserved");

    const mvp::PacketBuffer encoded_binary = mvp::encode_packet(packet, mvp::PacketFormat::BINARY_V2);
    expect_true(encoded_binary.size() == 64, "binary frame should have fixed 64-byte length");
    expect_true(encoded_binary.size() < encoded_json.size(), "binary frame should be smaller than json packet");
    mvp::OutputPacket decoded_binary;
    expect_true(
        mvp::decode_packet(mvp::PacketFormat::BINARY_V2, encoded_binary, &decoded_binary),
        "binary packet should decode successfully"
    );
    expect_true(decoded_binary.schema == "emg-glass.v2", "binary schema should decode as v2");
    expect_true(decoded_binary.seq == packet.seq, "binary seq should round-trip");
    expect_near(decoded_binary.emg[3], packet.emg[3], 0.001F, "binary emg_ch4 should round-trip");
    expect_near(decoded_binary.imus[0].accel[2], packet.imus[0].accel[2], 0.001F, "binary imu1 acc z should round-trip");
    expect_near(decoded_binary.imus[1].gyro[0], packet.imus[1].gyro[0], 0.01F, "binary imu2 gyro x should round-trip");
    expect_near(decoded_binary.imus[2].gyro[2], packet.imus[2].gyro[2], 0.01F, "binary imu3 gyro z should round-trip");
    expect_true(decoded_binary.state == packet.state, "binary state should round-trip");
    expect_true(decoded_binary.rep_index.has_value(), "binary rep_index should be preserved");
}

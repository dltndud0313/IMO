// JSON/BINARY 포맷을 모두 지원하는 wire packet 인코더/디코더 구현.
#include "packet.h"

#include <algorithm>
#include <cctype>
#include <charconv>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>

#include "config.h"

namespace mvp {
namespace {

constexpr uint16_t kBinaryMagic = 0x454DU;
constexpr uint8_t kBinaryPacketTypeSensorFrame = 1U;
constexpr uint16_t kBinaryPayloadLength = 56U;
constexpr std::size_t kBinaryFrameLength = 64U;
constexpr float kEmgScale = 1000.0F;
constexpr float kAccelScale = 1000.0F;
constexpr float kGyroScale = 100.0F;
constexpr int16_t kRepIndexMissing = -1;

std::string escape_json_string(const std::string& value) {
    std::string escaped;
    escaped.reserve(value.size());
    for (const char ch : value) {
        if (ch == '\"' || ch == '\\') {
            escaped.push_back('\\');
        }
        escaped.push_back(ch);
    }
    return escaped;
}

std::optional<std::string> extract_string(std::string_view line, std::string_view key) {
    const std::string token = "\"" + std::string(key) + "\"";
    const std::size_t key_pos = line.find(token);
    if (key_pos == std::string_view::npos) {
        return std::nullopt;
    }

    const std::size_t colon_pos = line.find(':', key_pos + token.size());
    if (colon_pos == std::string_view::npos) {
        return std::nullopt;
    }

    const std::size_t value_start = line.find('\"', colon_pos + 1);
    if (value_start == std::string_view::npos) {
        return std::nullopt;
    }

    const std::size_t value_end = line.find('\"', value_start + 1);
    if (value_end == std::string_view::npos || value_end <= value_start) {
        return std::nullopt;
    }

    return std::string(line.substr(value_start + 1, value_end - value_start - 1));
}

template <typename NumberType>
std::optional<NumberType> extract_number(std::string_view line, std::string_view key) {
    const std::string token = "\"" + std::string(key) + "\"";
    const std::size_t key_pos = line.find(token);
    if (key_pos == std::string_view::npos) {
        return std::nullopt;
    }

    const std::size_t colon_pos = line.find(':', key_pos + token.size());
    if (colon_pos == std::string_view::npos) {
        return std::nullopt;
    }

    std::size_t value_start = colon_pos + 1;
    while (value_start < line.size() && std::isspace(static_cast<unsigned char>(line[value_start])) != 0) {
        ++value_start;
    }

    std::size_t value_end = value_start;
    while (
        value_end < line.size() &&
        line[value_end] != ',' &&
        line[value_end] != '}' &&
        std::isspace(static_cast<unsigned char>(line[value_end])) == 0
    ) {
        ++value_end;
    }

    if (value_start == value_end) {
        return std::nullopt;
    }

    NumberType value {};
    const std::string numeric_text(line.substr(value_start, value_end - value_start));
    const auto [ptr, error_code] = std::from_chars(
        numeric_text.data(),
        numeric_text.data() + numeric_text.size(),
        value
    );
    if (error_code != std::errc() || ptr != numeric_text.data() + numeric_text.size()) {
        return std::nullopt;
    }

    return value;
}

void append_u8(PacketBuffer& buffer, uint8_t value) {
    buffer.push_back(value);
}

void append_u16_le(PacketBuffer& buffer, uint16_t value) {
    buffer.push_back(static_cast<uint8_t>(value & 0xFFU));
    buffer.push_back(static_cast<uint8_t>((value >> 8U) & 0xFFU));
}

void append_u32_le(PacketBuffer& buffer, uint32_t value) {
    buffer.push_back(static_cast<uint8_t>(value & 0xFFU));
    buffer.push_back(static_cast<uint8_t>((value >> 8U) & 0xFFU));
    buffer.push_back(static_cast<uint8_t>((value >> 16U) & 0xFFU));
    buffer.push_back(static_cast<uint8_t>((value >> 24U) & 0xFFU));
}

void append_i16_le(PacketBuffer& buffer, int16_t value) {
    append_u16_le(buffer, static_cast<uint16_t>(value));
}

uint8_t read_u8(const uint8_t* data, std::size_t offset) {
    return data[offset];
}

uint16_t read_u16_le(const uint8_t* data, std::size_t offset) {
    return static_cast<uint16_t>(data[offset]) |
           static_cast<uint16_t>(static_cast<uint16_t>(data[offset + 1U]) << 8U);
}

uint32_t read_u32_le(const uint8_t* data, std::size_t offset) {
    return static_cast<uint32_t>(data[offset]) |
           (static_cast<uint32_t>(data[offset + 1U]) << 8U) |
           (static_cast<uint32_t>(data[offset + 2U]) << 16U) |
           (static_cast<uint32_t>(data[offset + 3U]) << 24U);
}

int16_t read_i16_le(const uint8_t* data, std::size_t offset) {
    return static_cast<int16_t>(read_u16_le(data, offset));
}

uint16_t crc16_ccitt_false(const uint8_t* data, std::size_t size) {
    uint16_t crc = 0xFFFFU;
    for (std::size_t index = 0; index < size; ++index) {
        crc ^= static_cast<uint16_t>(data[index]) << 8U;
        for (int bit = 0; bit < 8; ++bit) {
            if ((crc & 0x8000U) != 0U) {
                crc = static_cast<uint16_t>((crc << 1U) ^ 0x1021U);
            } else {
                crc = static_cast<uint16_t>(crc << 1U);
            }
        }
    }
    return crc;
}

int16_t scale_to_i16(float value, float scale) {
    const float scaled = std::round(value * scale);
    const float clamped = std::clamp(scaled, -32768.0F, 32767.0F);
    return static_cast<int16_t>(clamped);
}

float unscale_i16(int16_t value, float scale) {
    return static_cast<float>(value) / scale;
}

int16_t rep_index_to_i16(const std::optional<int32_t>& rep_index) {
    if (!rep_index.has_value()) {
        return kRepIndexMissing;
    }
    const int32_t clamped = std::clamp(
        rep_index.value(),
        static_cast<int32_t>(-32768),
        static_cast<int32_t>(32767)
    );
    return static_cast<int16_t>(clamped);
}

RuntimeState runtime_state_from_code(uint8_t code) {
    switch (code) {
        case 0:
            return RuntimeState::IDLE;
        case 1:
            return RuntimeState::STREAMING;
        case 2:
            return RuntimeState::ERROR;
        default:
            return RuntimeState::ERROR;
    }
}

PacketBuffer encode_packet_json(const OutputPacket& packet) {
    std::ostringstream stream;
    stream << std::fixed << std::setprecision(4);
    stream << "{"
           << "\"schema\":\"" << escape_json_string(packet.schema) << "\","
           << "\"seq\":" << packet.seq << ","
           << "\"timestamp_ms\":" << packet.timestamp_ms << ","
           << "\"emg_ch1\":" << packet.emg[0] << ","
           << "\"emg_ch2\":" << packet.emg[1] << ","
           << "\"emg_ch3\":" << packet.emg[2] << ","
           << "\"emg_ch4\":" << packet.emg[3] << ","
           << "\"acc_x\":" << packet.imus[0].accel[0] << ","
           << "\"acc_y\":" << packet.imus[0].accel[1] << ","
           << "\"acc_z\":" << packet.imus[0].accel[2] << ","
           << "\"gyro_x\":" << packet.imus[0].gyro[0] << ","
           << "\"gyro_y\":" << packet.imus[0].gyro[1] << ","
           << "\"gyro_z\":" << packet.imus[0].gyro[2] << ",";

    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        const std::size_t imu_id = imu_index + 1U;
        stream << "\"imu" << imu_id << "_acc_x\":" << packet.imus[imu_index].accel[0] << ","
               << "\"imu" << imu_id << "_acc_y\":" << packet.imus[imu_index].accel[1] << ","
               << "\"imu" << imu_id << "_acc_z\":" << packet.imus[imu_index].accel[2] << ","
               << "\"imu" << imu_id << "_gyro_x\":" << packet.imus[imu_index].gyro[0] << ","
               << "\"imu" << imu_id << "_gyro_y\":" << packet.imus[imu_index].gyro[1] << ","
               << "\"imu" << imu_id << "_gyro_z\":" << packet.imus[imu_index].gyro[2] << ",";
    }

    stream << "\"state\":\"" << escape_json_string(packet.state) << "\","
           << "\"flags\":" << packet.flags;

    if (packet.rep_index.has_value()) {
        stream << ",\"rep_index\":" << packet.rep_index.value();
    }

    stream << "}\n";
    const std::string text = stream.str();
    return PacketBuffer(text.begin(), text.end());
}

PacketBuffer encode_packet_binary(const OutputPacket& packet) {
    PacketBuffer buffer;
    buffer.reserve(kBinaryFrameLength);

    append_u16_le(buffer, kBinaryMagic);
    append_u8(buffer, kPacketProtocolVersionBinaryV2);
    append_u8(buffer, kBinaryPacketTypeSensorFrame);
    append_u16_le(buffer, kBinaryPayloadLength);

    append_u32_le(buffer, packet.seq);
    append_u32_le(buffer, packet.timestamp_ms);

    for (std::size_t channel = 0; channel < kEmgChannelCount; ++channel) {
        append_i16_le(buffer, scale_to_i16(packet.emg[channel], kEmgScale));
    }

    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        append_i16_le(buffer, scale_to_i16(packet.imus[imu_index].accel[0], kAccelScale));
        append_i16_le(buffer, scale_to_i16(packet.imus[imu_index].accel[1], kAccelScale));
        append_i16_le(buffer, scale_to_i16(packet.imus[imu_index].accel[2], kAccelScale));
        append_i16_le(buffer, scale_to_i16(packet.imus[imu_index].gyro[0], kGyroScale));
        append_i16_le(buffer, scale_to_i16(packet.imus[imu_index].gyro[1], kGyroScale));
        append_i16_le(buffer, scale_to_i16(packet.imus[imu_index].gyro[2], kGyroScale));
    }

    append_u8(buffer, static_cast<uint8_t>(runtime_state_from_string(packet.state)));
    append_u8(buffer, static_cast<uint8_t>(packet.flags & 0xFFU));
    append_i16_le(buffer, rep_index_to_i16(packet.rep_index));

    const uint16_t crc = crc16_ccitt_false(buffer.data(), buffer.size());
    append_u16_le(buffer, crc);
    return buffer;
}

bool decode_packet_json(const uint8_t* data, std::size_t size, OutputPacket* packet) {
    std::string_view line(reinterpret_cast<const char*>(data), size);
    while (!line.empty() && (line.back() == '\n' || line.back() == '\r')) {
        line.remove_suffix(1);
    }

    const auto schema = extract_string(line, "schema");
    const auto seq = extract_number<uint32_t>(line, "seq");
    const auto timestamp = extract_number<uint32_t>(line, "timestamp_ms");
    const auto emg_ch1 = extract_number<float>(line, "emg_ch1");
    const auto emg_ch2 = extract_number<float>(line, "emg_ch2");
    const auto emg_ch3 = extract_number<float>(line, "emg_ch3");
    const auto emg_ch4 = extract_number<float>(line, "emg_ch4");
    const auto state = extract_string(line, "state");
    const auto flags = extract_number<uint32_t>(line, "flags");
    const auto acc_x = extract_number<float>(line, "acc_x");
    const auto acc_y = extract_number<float>(line, "acc_y");
    const auto acc_z = extract_number<float>(line, "acc_z");
    const auto gyro_x = extract_number<float>(line, "gyro_x");
    const auto gyro_y = extract_number<float>(line, "gyro_y");
    const auto gyro_z = extract_number<float>(line, "gyro_z");

    if (
        !schema.has_value() || !seq.has_value() || !timestamp.has_value() ||
        !emg_ch1.has_value() || !emg_ch2.has_value() || !emg_ch3.has_value() || !emg_ch4.has_value() ||
        !state.has_value() || !flags.has_value() ||
        !acc_x.has_value() || !acc_y.has_value() || !acc_z.has_value() ||
        !gyro_x.has_value() || !gyro_y.has_value() || !gyro_z.has_value()
    ) {
        return false;
    }

    packet->schema = schema.value();
    packet->seq = seq.value();
    packet->timestamp_ms = timestamp.value();
    packet->emg = {emg_ch1.value(), emg_ch2.value(), emg_ch3.value(), emg_ch4.value()};
    packet->imus[0].accel = {acc_x.value(), acc_y.value(), acc_z.value()};
    packet->imus[0].gyro = {gyro_x.value(), gyro_y.value(), gyro_z.value()};

    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        const std::size_t imu_id = imu_index + 1U;
        const std::string prefix = "imu" + std::to_string(imu_id);
        const auto imu_acc_x = extract_number<float>(line, prefix + "_acc_x");
        const auto imu_acc_y = extract_number<float>(line, prefix + "_acc_y");
        const auto imu_acc_z = extract_number<float>(line, prefix + "_acc_z");
        const auto imu_gyro_x = extract_number<float>(line, prefix + "_gyro_x");
        const auto imu_gyro_y = extract_number<float>(line, prefix + "_gyro_y");
        const auto imu_gyro_z = extract_number<float>(line, prefix + "_gyro_z");
        if (
            imu_acc_x.has_value() && imu_acc_y.has_value() && imu_acc_z.has_value() &&
            imu_gyro_x.has_value() && imu_gyro_y.has_value() && imu_gyro_z.has_value()
        ) {
            packet->imus[imu_index].accel = {imu_acc_x.value(), imu_acc_y.value(), imu_acc_z.value()};
            packet->imus[imu_index].gyro = {imu_gyro_x.value(), imu_gyro_y.value(), imu_gyro_z.value()};
        } else if (imu_index != 0) {
            packet->imus[imu_index] = {};
        }
    }

    packet->state = state.value();
    packet->flags = flags.value();
    packet->rep_index = extract_number<int32_t>(line, "rep_index");
    return true;
}

bool decode_packet_binary(const uint8_t* data, std::size_t size, OutputPacket* packet) {
    if (size != kBinaryFrameLength) {
        return false;
    }

    const uint16_t magic = read_u16_le(data, 0);
    const uint8_t version = read_u8(data, 2);
    const uint8_t packet_type = read_u8(data, 3);
    const uint16_t payload_length = read_u16_le(data, 4);
    const uint16_t expected_crc = read_u16_le(data, size - 2U);
    const uint16_t actual_crc = crc16_ccitt_false(data, size - 2U);

    if (
        magic != kBinaryMagic ||
        version != kPacketProtocolVersionBinaryV2 ||
        packet_type != kBinaryPacketTypeSensorFrame ||
        payload_length != kBinaryPayloadLength ||
        expected_crc != actual_crc
    ) {
        return false;
    }

    packet->schema = kPacketSchemaBinaryV2;
    packet->seq = read_u32_le(data, 6);
    packet->timestamp_ms = read_u32_le(data, 10);

    std::size_t offset = 14;
    for (std::size_t channel = 0; channel < kEmgChannelCount; ++channel) {
        packet->emg[channel] = unscale_i16(read_i16_le(data, offset), kEmgScale);
        offset += 2;
    }

    for (std::size_t imu_index = 0; imu_index < kImuSensorCount; ++imu_index) {
        packet->imus[imu_index].accel = {
            unscale_i16(read_i16_le(data, offset), kAccelScale),
            unscale_i16(read_i16_le(data, offset + 2), kAccelScale),
            unscale_i16(read_i16_le(data, offset + 4), kAccelScale),
        };
        packet->imus[imu_index].gyro = {
            unscale_i16(read_i16_le(data, offset + 6), kGyroScale),
            unscale_i16(read_i16_le(data, offset + 8), kGyroScale),
            unscale_i16(read_i16_le(data, offset + 10), kGyroScale),
        };
        offset += 12;
    }

    packet->state = to_string(runtime_state_from_code(read_u8(data, 58)));
    packet->flags = read_u8(data, 59);

    const int16_t rep_index = read_i16_le(data, 60);
    if (rep_index == kRepIndexMissing) {
        packet->rep_index = std::nullopt;
    } else {
        packet->rep_index = rep_index;
    }

    return true;
}

}  // namespace

PacketBuffer encode_packet(const OutputPacket& packet, PacketFormat format) {
    switch (format) {
        case PacketFormat::JSON_V1:
            return encode_packet_json(packet);
        case PacketFormat::BINARY_V2:
            return encode_packet_binary(packet);
    }

    return encode_packet_json(packet);
}

bool decode_packet(PacketFormat format, const uint8_t* data, std::size_t size, OutputPacket* packet) {
    if (packet == nullptr || data == nullptr) {
        return false;
    }

    switch (format) {
        case PacketFormat::JSON_V1:
            return decode_packet_json(data, size, packet);
        case PacketFormat::BINARY_V2:
            return decode_packet_binary(data, size, packet);
    }

    return false;
}

std::string packet_format_name(PacketFormat format) {
    switch (format) {
        case PacketFormat::JSON_V1:
            return "json-v1";
        case PacketFormat::BINARY_V2:
            return "binary-v2";
    }

    return "unknown";
}

}  // namespace mvp

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
constexpr uint16_t kBinaryPayloadLength = 30U;
constexpr std::size_t kBinaryFrameLength = 38U;
constexpr float kEmgScale = 1000.0F;
constexpr float kImuScale = 1000.0F;
constexpr int16_t kRepIndexMissing = -1;

std::string escape_json_string(const std::string& value) {
    std::string escaped;
    escaped.reserve(value.size());
    for (const char ch : value) {
        // 최소한의 escape만 적용해 디버깅 가능한 JSONL 형식을 유지한다.
        if (ch == '\"' || ch == '\\') {
            escaped.push_back('\\');
        }
        escaped.push_back(ch);
    }
    return escaped;
}

std::optional<std::string> extract_string(std::string_view line, std::string_view key) {
    // 외부 JSON 라이브러리 없이 host 테스트까지 돌리기 위해 단순 key 검색으로 파싱한다.
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
    // std::from_chars는 동적 할당 없이 숫자 파싱이 가능해 MCU/host 공용 코드에 유리하다.
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
    const int32_t clamped = std::clamp(rep_index.value(), -32768, 32767);
    return static_cast<int16_t>(clamped);
}

RuntimeState runtime_state_from_code(uint8_t code) {
    switch (code) {
        case 0:
            return RuntimeState::IDLE;
        case 1:
            return RuntimeState::CALIBRATION_REST;
        case 2:
            return RuntimeState::CALIBRATION_MVC;
        case 3:
            return RuntimeState::READY;
        case 4:
            return RuntimeState::STREAMING;
        case 5:
            return RuntimeState::ERROR;
        default:
            return RuntimeState::ERROR;
    }
}

PacketBuffer encode_packet_json(const OutputPacket& packet) {
    std::ostringstream stream;
    // 로그 비교와 테스트 재현성을 위해 실수는 고정 소수점 4자리로 맞춘다.
    stream << std::fixed << std::setprecision(4);
    stream << "{"
           << "\"schema\":\"" << escape_json_string(packet.schema) << "\","
           << "\"seq\":" << packet.seq << ","
           << "\"timestamp_ms\":" << packet.timestamp_ms << ","
           << "\"emg_ch1\":" << packet.emg_ch1 << ","
           << "\"emg_ch2\":" << packet.emg_ch2 << ","
           << "\"emg_ch3\":" << packet.emg_ch3 << ","
           << "\"acc_x\":" << packet.acc_x << ","
           << "\"acc_y\":" << packet.acc_y << ","
           << "\"acc_z\":" << packet.acc_z << ","
           << "\"gyro_x\":" << packet.gyro_x << ","
           << "\"gyro_y\":" << packet.gyro_y << ","
           << "\"gyro_z\":" << packet.gyro_z << ","
           << "\"state\":\"" << escape_json_string(packet.state) << "\","
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
    append_i16_le(buffer, scale_to_i16(packet.emg_ch1, kEmgScale));
    append_i16_le(buffer, scale_to_i16(packet.emg_ch2, kEmgScale));
    append_i16_le(buffer, scale_to_i16(packet.emg_ch3, kEmgScale));
    append_i16_le(buffer, scale_to_i16(packet.acc_x, kImuScale));
    append_i16_le(buffer, scale_to_i16(packet.acc_y, kImuScale));
    append_i16_le(buffer, scale_to_i16(packet.acc_z, kImuScale));
    append_i16_le(buffer, scale_to_i16(packet.gyro_x, kImuScale));
    append_i16_le(buffer, scale_to_i16(packet.gyro_y, kImuScale));
    append_i16_le(buffer, scale_to_i16(packet.gyro_z, kImuScale));
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
    const auto acc_x = extract_number<float>(line, "acc_x");
    const auto acc_y = extract_number<float>(line, "acc_y");
    const auto acc_z = extract_number<float>(line, "acc_z");
    const auto gyro_x = extract_number<float>(line, "gyro_x");
    const auto gyro_y = extract_number<float>(line, "gyro_y");
    const auto gyro_z = extract_number<float>(line, "gyro_z");
    const auto state = extract_string(line, "state");
    const auto flags = extract_number<uint32_t>(line, "flags");

    if (
        !schema.has_value() ||
        !seq.has_value() ||
        !timestamp.has_value() ||
        !emg_ch1.has_value() ||
        !emg_ch2.has_value() ||
        !emg_ch3.has_value() ||
        !acc_x.has_value() ||
        !acc_y.has_value() ||
        !acc_z.has_value() ||
        !gyro_x.has_value() ||
        !gyro_y.has_value() ||
        !gyro_z.has_value() ||
        !state.has_value() ||
        !flags.has_value()
    ) {
        return false;
    }

    packet->schema = schema.value();
    packet->seq = seq.value();
    packet->timestamp_ms = timestamp.value();
    packet->emg_ch1 = emg_ch1.value();
    packet->emg_ch2 = emg_ch2.value();
    packet->emg_ch3 = emg_ch3.value();
    packet->acc_x = acc_x.value();
    packet->acc_y = acc_y.value();
    packet->acc_z = acc_z.value();
    packet->gyro_x = gyro_x.value();
    packet->gyro_y = gyro_y.value();
    packet->gyro_z = gyro_z.value();
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
    packet->emg_ch1 = unscale_i16(read_i16_le(data, 14), kEmgScale);
    packet->emg_ch2 = unscale_i16(read_i16_le(data, 16), kEmgScale);
    packet->emg_ch3 = unscale_i16(read_i16_le(data, 18), kEmgScale);
    packet->acc_x = unscale_i16(read_i16_le(data, 20), kImuScale);
    packet->acc_y = unscale_i16(read_i16_le(data, 22), kImuScale);
    packet->acc_z = unscale_i16(read_i16_le(data, 24), kImuScale);
    packet->gyro_x = unscale_i16(read_i16_le(data, 26), kImuScale);
    packet->gyro_y = unscale_i16(read_i16_le(data, 28), kImuScale);
    packet->gyro_z = unscale_i16(read_i16_le(data, 30), kImuScale);
    packet->state = to_string(runtime_state_from_code(read_u8(data, 32)));
    packet->flags = read_u8(data, 33);

    const int16_t rep_index = read_i16_le(data, 34);
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

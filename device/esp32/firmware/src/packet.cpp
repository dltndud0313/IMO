// 외부 라이브러리 없이 동작하는 JSONL 인코더/디코더 구현. g++만으로 host 테스트 가능.
#include "packet.h"

#include <cctype>
#include <charconv>
#include <iomanip>
#include <optional>
#include <sstream>
#include <string>

namespace mvp {
namespace {

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

}  // namespace

std::string encode_packet(const OutputPacket& packet) {
    std::ostringstream stream;
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

    stream << "}";
    return stream.str();
}

bool decode_packet(std::string_view line, OutputPacket* packet) {
    if (packet == nullptr) {
        return false;
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

}  // namespace mvp

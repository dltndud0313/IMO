// ESP32 펌웨어와 Pi 수신기 사이에서 사용하는 wire packet 인터페이스.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

#include "types.h"

namespace mvp {

using PacketBuffer = std::vector<uint8_t>;

PacketBuffer encode_packet(const OutputPacket& packet, PacketFormat format);
bool decode_packet(PacketFormat format, const uint8_t* data, std::size_t size, OutputPacket* packet);

inline bool decode_packet(PacketFormat format, const PacketBuffer& buffer, OutputPacket* packet) {
    return decode_packet(format, buffer.data(), buffer.size(), packet);
}

std::string packet_format_name(PacketFormat format);

}  // namespace mvp

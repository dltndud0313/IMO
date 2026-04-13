// ESP32 펌웨어와 Pi 수신기 사이에서 사용하는 JSON Lines 패킷 인터페이스.
#pragma once

#include <string>
#include <string_view>

#include "types.h"

namespace mvp {

std::string encode_packet(const OutputPacket& packet);
bool decode_packet(std::string_view line, OutputPacket* packet);

}  // namespace mvp

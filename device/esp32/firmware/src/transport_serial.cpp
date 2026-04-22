// 기본 전송은 stdout byte stream 출력. 이후 MQTT 등 다른 전송 매체도 같은 버퍼를 재사용한다.
#include "transport_serial.h"

#include <cstdio>
#include <utility>

namespace mvp {
namespace {

void default_sink(const PacketBuffer& payload) {
    if (!payload.empty()) {
        std::fwrite(payload.data(), sizeof(uint8_t), payload.size(), stdout);
    }
    std::fflush(stdout);
}

}  // namespace

SerialTransport::SerialTransport(PacketFormat format, Sink sink)
    : format_(format), sink_(sink ? std::move(sink) : Sink(default_sink)) {}

bool SerialTransport::send_packet(const OutputPacket& packet) const {
    sink_(encode_packet(packet, format_));
    return true;
}

PacketFormat SerialTransport::packet_format() const {
    return format_;
}

}  // namespace mvp

// 기본 전송은 stdout(JSONL) 출력. 실제 디바이스에선 Serial 출력으로 쉽게 치환 가능.
#include "transport_serial.h"

#include <cstdio>

namespace mvp {
namespace {

void default_sink(const std::string& line) {
    std::fputs(line.c_str(), stdout);
    std::fputc('\n', stdout);
}

}  // namespace

SerialTransport::SerialTransport(Sink sink)
    : sink_(sink ? std::move(sink) : Sink(default_sink)) {}

bool SerialTransport::send_packet(const OutputPacket& packet) const {
    sink_(encode_packet(packet));
    return true;
}

}  // namespace mvp

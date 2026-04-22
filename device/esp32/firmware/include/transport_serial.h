// MVP 검증용 Serial 라인 전송 계층. 이후 BLE/Wi-Fi도 같은 출력 계약을 따르도록 설계.
#pragma once

#include <functional>

#include "packet.h"

namespace mvp {

class SerialTransport {
  public:
    using Sink = std::function<void(const PacketBuffer&)>;

    explicit SerialTransport(PacketFormat format = PacketFormat::JSON_V1, Sink sink = {});
    bool send_packet(const OutputPacket& packet) const;
    PacketFormat packet_format() const;

  private:
    PacketFormat format_;
    Sink sink_;
};

}  // namespace mvp

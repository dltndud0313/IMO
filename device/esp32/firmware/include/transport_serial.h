// MVP 검증용 Serial 라인 전송 계층. 이후 BLE/Wi-Fi도 같은 출력 계약을 따르도록 설계.
#pragma once

#include <functional>
#include <string>

#include "packet.h"

namespace mvp {

class SerialTransport {
  public:
    using Sink = std::function<void(const std::string&)>;

    explicit SerialTransport(Sink sink = {});
    bool send_packet(const OutputPacket& packet) const;

  private:
    Sink sink_;
};

}  // namespace mvp

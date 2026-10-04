#pragma once
#include <VISROS/DeviceEmulator/IDeviceTransport.hpp>
#include <VISROS/VirtualDisplay/RfbClient.hpp>
#include <cstdint>
#include <string>
namespace VISROS::DeviceEmulator {
class RfbTransport final:public IDeviceTransport {
public:
 explicit RfbTransport(std::string host="127.0.0.1",std::uint16_t port=5901); ~RfbTransport() override;
 RfbTransport(const RfbTransport&)=delete; RfbTransport& operator=(const RfbTransport&)=delete;
 void Poll(EmulatedXRDevice&) override; [[nodiscard]] bool Connected()const noexcept override; [[nodiscard]] std::string_view Name()const noexcept override;
private: std::string name_; VirtualDisplay::RfbClient client_;
};
}

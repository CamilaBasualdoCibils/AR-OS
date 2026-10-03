#pragma once

#include <AROS/DeviceEmulator/IDeviceTransport.hpp>

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace AROS::DeviceEmulator {

class RfbTransport final : public IDeviceTransport {
public:
    explicit RfbTransport(std::string host = "127.0.0.1", std::uint16_t port = 5901);
    ~RfbTransport() override;

    RfbTransport(const RfbTransport&) = delete;
    RfbTransport& operator=(const RfbTransport&) = delete;

    void Poll(EmulatedXRDevice& device) override;
    [[nodiscard]] bool Connected() const noexcept override;
    [[nodiscard]] std::string_view Name() const noexcept override;

private:
    void Run(std::stop_token stopToken);
    void RunConnection(int socket, std::stop_token stopToken);

    std::string host_;
    std::uint16_t port_;
    std::string name_;
    std::jthread worker_;
    std::atomic_bool connected_ {false};
    std::atomic_int socket_ {-1};

    std::mutex frameMutex_;
    std::vector<std::uint8_t> pendingFrame_;
    std::uint32_t pendingWidth_ {};
    std::uint32_t pendingHeight_ {};
    std::uint64_t pendingGeneration_ {};
    std::uint64_t consumedGeneration_ {};
};

} // namespace AROS::DeviceEmulator

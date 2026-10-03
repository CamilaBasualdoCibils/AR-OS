#pragma once

#include <AROS/DeviceEmulator/IDeviceTransport.hpp>
#include <AROS/DeviceEmulator/RfbTransport.hpp>
#include <array>
#include <atomic>
#include <cstdint>
#include <mutex>
#include <thread>
#include <vector>

namespace AROS::DeviceEmulator {

class SandboxTransport final : public IDeviceTransport {
public:
    SandboxTransport();
    ~SandboxTransport() override;
    SandboxTransport(const SandboxTransport&) = delete;
    SandboxTransport& operator=(const SandboxTransport&) = delete;

    void Poll(EmulatedXRDevice& device) override;
    [[nodiscard]] bool Connected() const noexcept override;
    [[nodiscard]] std::string_view Name() const noexcept override;

private:
    struct Frame {
        std::uint8_t eye {};
        std::uint32_t width {};
        std::uint32_t height {};
        std::vector<std::uint8_t> pixels;
        std::uint64_t generation {};
    };
    void Run(std::stop_token stopToken);

    RfbTransport rfb_;
    std::jthread worker_;
    std::atomic_bool xrConnected_ {false};
    std::atomic_int socket_ {-1};
    std::mutex mutex_;
    std::array<Frame, 2> pending_;
    std::uint64_t nextGeneration_ {1};
    std::array<std::uint64_t, 2> consumedGeneration_ {};
};

} // namespace AROS::DeviceEmulator

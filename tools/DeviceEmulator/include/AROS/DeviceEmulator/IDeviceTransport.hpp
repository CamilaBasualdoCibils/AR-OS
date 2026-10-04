#pragma once

#include <string_view>

namespace AROS::DeviceEmulator {

class EmulatedXRDevice;
struct Pose;

class IDeviceTransport {
public:
    virtual ~IDeviceTransport() = default;

    virtual void Poll(EmulatedXRDevice& device) = 0;
    virtual void SetHeadState(const Pose&, float) {}
    [[nodiscard]] virtual bool Connected() const noexcept = 0;
    [[nodiscard]] virtual std::string_view Name() const noexcept = 0;
};

class DisconnectedTransport final : public IDeviceTransport {
public:
    void Poll(EmulatedXRDevice& device) override;
    void SetHeadState(const Pose&, float) override {}
    [[nodiscard]] bool Connected() const noexcept override;
    [[nodiscard]] std::string_view Name() const noexcept override;
};

} // namespace AROS::DeviceEmulator

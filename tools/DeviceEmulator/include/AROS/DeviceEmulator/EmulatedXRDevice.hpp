#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <vector>

namespace AROS::DeviceEmulator {

enum class DeviceMode {
    BootDisplay,
    OpenXR,
};

enum class Eye {
    Left,
    Right,
};

struct Pose {
    std::array<float, 3> position {0.0F, 0.0F, 0.0F};
    std::array<float, 4> orientation {0.0F, 0.0F, 0.0F, 1.0F};
};

struct EmulatedHead {
    Pose pose {};
};

struct DeviceCapabilities {
    bool stereoDisplay {true};
    bool headTracking {false};
    bool handTracking {false};
};

struct EyeImage {
    std::uint32_t width {};
    std::uint32_t height {};
    std::vector<std::uint8_t> rgbaPixels;
    std::uint64_t generation {};
};

class EmulatedXRDevice {
public:
    EmulatedXRDevice();

    void SubmitBootImage(
        std::uint32_t width,
        std::uint32_t height,
        std::span<const std::uint8_t> rgbaPixels);
    void SubmitEyeImage(
        Eye eye,
        std::uint32_t width,
        std::uint32_t height,
        std::span<const std::uint8_t> rgbaPixels);

    void SetMode(DeviceMode mode) noexcept;
    void SetConnected(bool connected) noexcept;
    void SetOpenXRSessionActive(bool active) noexcept;

    [[nodiscard]] const EyeImage& Image(Eye eye) const noexcept;
    [[nodiscard]] DeviceMode Mode() const noexcept;
    [[nodiscard]] bool Connected() const noexcept;
    [[nodiscard]] bool OpenXRSessionActive() const noexcept;
    [[nodiscard]] const EmulatedHead& Head() const noexcept;
    [[nodiscard]] const DeviceCapabilities& Capabilities() const noexcept;

private:
    void StoreImage(
        EyeImage& destination,
        std::uint32_t width,
        std::uint32_t height,
        std::span<const std::uint8_t> rgbaPixels);

    EyeImage leftEye_;
    EyeImage rightEye_;
    DeviceMode mode_ {DeviceMode::BootDisplay};
    bool connected_ {false};
    bool openXRSessionActive_ {false};
    EmulatedHead head_ {};
    DeviceCapabilities capabilities_ {};
    std::uint64_t nextGeneration_ {1};
};

} // namespace AROS::DeviceEmulator

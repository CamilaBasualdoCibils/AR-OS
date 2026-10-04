#include <VISROS/DeviceEmulator/EmulatedXRDevice.hpp>

#include <algorithm>
#include <limits>
#include <stdexcept>

namespace VISROS::DeviceEmulator {
namespace {

constexpr std::uint32_t kPlaceholderWidth = 640;
constexpr std::uint32_t kPlaceholderHeight = 480;

std::vector<std::uint8_t> MakePlaceholderPixels()
{
    std::vector<std::uint8_t> pixels(
        static_cast<std::size_t>(kPlaceholderWidth) * kPlaceholderHeight * 4U);

    for (std::uint32_t y = 0; y < kPlaceholderHeight; ++y) {
        for (std::uint32_t x = 0; x < kPlaceholderWidth; ++x) {
            const auto offset = (static_cast<std::size_t>(y) * kPlaceholderWidth + x) * 4U;
            const bool alternate = ((x / 32U) + (y / 32U)) % 2U == 0U;
            const std::uint8_t value = alternate ? 24U : 31U;
            pixels[offset + 0U] = value;
            pixels[offset + 1U] = value;
            pixels[offset + 2U] = static_cast<std::uint8_t>(value + 4U);
            pixels[offset + 3U] = 255U;
        }
    }
    return pixels;
}

} // namespace

EmulatedXRDevice::EmulatedXRDevice()
{
    const auto placeholder = MakePlaceholderPixels();
    SubmitBootImage(kPlaceholderWidth, kPlaceholderHeight, placeholder);
    StoreImage(openXRLeftEye_, kPlaceholderWidth, kPlaceholderHeight, placeholder);
    StoreImage(openXRRightEye_, kPlaceholderWidth, kPlaceholderHeight, placeholder);
}

void EmulatedXRDevice::SubmitBootImage(
    const std::uint32_t width,
    const std::uint32_t height,
    const std::span<const std::uint8_t> rgbaPixels)
{
    StoreImage(bootImage_, width, height, rgbaPixels);
}

void EmulatedXRDevice::SubmitEyeImage(
    const Eye eye,
    const std::uint32_t width,
    const std::uint32_t height,
    const std::span<const std::uint8_t> rgbaPixels)
{
    StoreImage(eye == Eye::Left ? openXRLeftEye_ : openXRRightEye_,
               width, height, rgbaPixels);
}

void EmulatedXRDevice::SetMode(const DeviceMode mode) noexcept
{
    mode_ = mode;
}

void EmulatedXRDevice::SetConnected(const bool connected) noexcept
{
    connected_ = connected;
    if (!connected_) {
        openXRSessionActive_ = false;
    }
}

void EmulatedXRDevice::SetOpenXRSessionActive(const bool active) noexcept
{
    const bool wasActive = openXRSessionActive_;
    openXRSessionActive_ = active && connected_;
    if (openXRSessionActive_ && !wasActive) {
        mode_ = DeviceMode::OpenXR;
    }
}

const EyeImage& EmulatedXRDevice::Image(const Eye eye) const noexcept
{
    if (mode_ == DeviceMode::BootDisplay) {
        return bootImage_;
    }
    return eye == Eye::Left ? openXRLeftEye_ : openXRRightEye_;
}

DeviceMode EmulatedXRDevice::Mode() const noexcept { return mode_; }
bool EmulatedXRDevice::Connected() const noexcept { return connected_; }
bool EmulatedXRDevice::OpenXRSessionActive() const noexcept { return openXRSessionActive_; }
const EmulatedHead& EmulatedXRDevice::Head() const noexcept { return head_; }
const DeviceCapabilities& EmulatedXRDevice::Capabilities() const noexcept { return capabilities_; }

void EmulatedXRDevice::StoreImage(
    EyeImage& destination,
    const std::uint32_t width,
    const std::uint32_t height,
    const std::span<const std::uint8_t> rgbaPixels)
{
    if (width == 0U || height == 0U) {
        throw std::invalid_argument("eye image dimensions must be non-zero");
    }
    if (width > std::numeric_limits<std::size_t>::max() / height / 4U) {
        throw std::invalid_argument("eye image dimensions are too large");
    }
    const auto expectedSize = static_cast<std::size_t>(width) * height * 4U;
    if (rgbaPixels.size() != expectedSize) {
        throw std::invalid_argument("eye image must contain tightly packed RGBA8 pixels");
    }

    destination.width = width;
    destination.height = height;
    destination.rgbaPixels.assign(rgbaPixels.begin(), rgbaPixels.end());
    destination.generation = nextGeneration_++;
}

} // namespace VISROS::DeviceEmulator

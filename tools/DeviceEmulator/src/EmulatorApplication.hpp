#pragma once

#include <AROS/DeviceEmulator/EmulatedXRDevice.hpp>
#include <AROS/DeviceEmulator/IDeviceTransport.hpp>

#include <cstdint>
#include <memory>

struct GLFWwindow;

namespace AROS::DeviceEmulator {

class EmulatorApplication {
public:
    explicit EmulatorApplication(std::unique_ptr<IDeviceTransport> transport);
    ~EmulatorApplication();

    EmulatorApplication(const EmulatorApplication&) = delete;
    EmulatorApplication& operator=(const EmulatorApplication&) = delete;

    int Run();

private:
    struct Texture {
        unsigned int id {};
        std::uint64_t generation {};
    };

    void Initialize();
    void Shutdown() noexcept;
    void SynchronizeTexture(Texture& texture, const EyeImage& image);
    void DrawInterface();
    void DrawEyePanel(const char* title, Eye eye, const Texture& texture, float width, float height);
    void DrawStatus();

    GLFWwindow* window_ {};
    EmulatedXRDevice device_ {};
    std::unique_ptr<IDeviceTransport> transport_;
    Texture leftTexture_ {};
    Texture rightTexture_ {};
    bool initialized_ {false};
    Pose headPose_ {{0.0F, 1.6F, 0.0F}, {0.0F, 0.0F, 0.0F, 1.0F}};
    float interPupillaryDistance_ {0.064F};
    std::array<float, 3> headEulerDegrees_ {0.0F, 0.0F, 0.0F};
};

} // namespace AROS::DeviceEmulator

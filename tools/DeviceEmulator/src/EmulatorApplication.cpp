#include "EmulatorApplication.hpp"

#include <GLFW/glfw3.h>
#include <imgui.h>
#include <imgui_impl_glfw.h>
#include <imgui_impl_opengl3.h>

#include <algorithm>
#include <cstdio>
#include <stdexcept>
#include <utility>

namespace AROS::DeviceEmulator {
namespace {

constexpr const char* kGlslVersion = "#version 330";

void GlfwErrorCallback(const int code, const char* description)
{
    std::fprintf(stderr, "GLFW error %d: %s\n", code, description);
}

ImVec2 FitImage(const EyeImage& image, const ImVec2 available)
{
    const float imageAspect = static_cast<float>(image.width) / static_cast<float>(image.height);
    const float availableAspect = available.x / std::max(available.y, 1.0F);
    if (imageAspect > availableAspect) {
        return {available.x, available.x / imageAspect};
    }
    return {available.y * imageAspect, available.y};
}

const char* ModeName(const DeviceMode mode)
{
    return mode == DeviceMode::BootDisplay ? "Boot Display" : "OpenXR";
}

} // namespace

EmulatorApplication::EmulatorApplication(std::unique_ptr<IDeviceTransport> transport)
    : transport_(std::move(transport))
{
    if (!transport_) {
        throw std::invalid_argument("a device transport is required");
    }
}

EmulatorApplication::~EmulatorApplication() { Shutdown(); }

int EmulatorApplication::Run()
{
    Initialize();

    while (!glfwWindowShouldClose(window_)) {
        glfwPollEvents();
        transport_->Poll(device_);
        device_.SetConnected(transport_->Connected());

        SynchronizeTexture(leftTexture_, device_.Image(Eye::Left));
        SynchronizeTexture(rightTexture_, device_.Image(Eye::Right));

        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();
        DrawInterface();
        ImGui::Render();

        int framebufferWidth = 0;
        int framebufferHeight = 0;
        glfwGetFramebufferSize(window_, &framebufferWidth, &framebufferHeight);
        glViewport(0, 0, framebufferWidth, framebufferHeight);
        glClearColor(0.035F, 0.04F, 0.05F, 1.0F);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        glfwSwapBuffers(window_);
    }

    return 0;
}

void EmulatorApplication::Initialize()
{
    glfwSetErrorCallback(GlfwErrorCallback);
    if (glfwInit() != GLFW_TRUE) {
        throw std::runtime_error("failed to initialize GLFW");
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    window_ = glfwCreateWindow(1280, 800, "AR-OS Device Emulator", nullptr, nullptr);
    if (!window_) {
        glfwTerminate();
        throw std::runtime_error("failed to create the Device Emulator window");
    }
    glfwMakeContextCurrent(window_);
    glfwSwapInterval(1);

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::StyleColorsDark();
    float content_scale_x,
    content_scale_y;
    glfwGetWindowContentScale(window_, &content_scale_x, &content_scale_y);
    ImGui::GetStyle().FontScaleMain = content_scale_x;
    if (!ImGui_ImplGlfw_InitForOpenGL(window_, true)) {
        throw std::runtime_error("failed to initialize the ImGui GLFW backend");
    }
    if (!ImGui_ImplOpenGL3_Init(kGlslVersion)) {
        throw std::runtime_error("failed to initialize the ImGui OpenGL backend");
    }

    glGenTextures(1, &leftTexture_.id);
    glGenTextures(1, &rightTexture_.id);
    initialized_ = true;
}

void EmulatorApplication::Shutdown() noexcept
{
    if (initialized_) {
        glDeleteTextures(1, &leftTexture_.id);
        glDeleteTextures(1, &rightTexture_.id);
        ImGui_ImplOpenGL3_Shutdown();
        ImGui_ImplGlfw_Shutdown();
        ImGui::DestroyContext();
        initialized_ = false;
    }
    if (window_) {
        glfwDestroyWindow(window_);
        window_ = nullptr;
    }
    glfwTerminate();
}

void EmulatorApplication::SynchronizeTexture(Texture& texture, const EyeImage& image)
{
    if (texture.generation == image.generation) {
        return;
    }

    glBindTexture(GL_TEXTURE_2D, texture.id);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(
        GL_TEXTURE_2D,
        0,
        GL_RGBA8,
        static_cast<int>(image.width),
        static_cast<int>(image.height),
        0,
        GL_RGBA,
        GL_UNSIGNED_BYTE,
        image.rgbaPixels.data());
    texture.generation = image.generation;
}

void EmulatorApplication::DrawInterface()
{
    const ImGuiViewport* viewport = ImGui::GetMainViewport();
    ImGui::SetNextWindowPos(viewport->WorkPos);
    ImGui::SetNextWindowSize(viewport->WorkSize);

    constexpr ImGuiWindowFlags flags = ImGuiWindowFlags_NoDecoration
        | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings;
    ImGui::Begin("AR-OS Device Emulator", nullptr, flags);
    ImGui::TextUnformatted("AR-OS Device Emulator");
    ImGui::Separator();

    const ImVec2 available = ImGui::GetContentRegionAvail();
    const float statusHeight = 145.0F;
    const float eyeHeight = std::max(220.0F, available.y - statusHeight);
    const float spacing = ImGui::GetStyle().ItemSpacing.x;
    const float eyeWidth = (available.x - spacing) * 0.5F;

    DrawEyePanel("LEFT EYE", Eye::Left, leftTexture_, eyeWidth, eyeHeight);
    ImGui::SameLine();
    DrawEyePanel("RIGHT EYE", Eye::Right, rightTexture_, eyeWidth, eyeHeight);
    DrawStatus();
    ImGui::End();
}

void EmulatorApplication::DrawEyePanel(
    const char* title,
    const Eye eye,
    const Texture& texture,
    const float width,
    const float height)
{
    ImGui::BeginChild(title, {width, height}, ImGuiChildFlags_Borders);
    const float titleWidth = ImGui::CalcTextSize(title).x;
    ImGui::SetCursorPosX((ImGui::GetContentRegionAvail().x - titleWidth) * 0.5F);
    ImGui::TextUnformatted(title);

    const EyeImage& image = device_.Image(eye);
    const ImVec2 available = ImGui::GetContentRegionAvail();
    const ImVec2 imageSize = FitImage(image, available);
    ImGui::SetCursorPosX(ImGui::GetCursorPosX() + (available.x - imageSize.x) * 0.5F);
    ImGui::SetCursorPosY(ImGui::GetCursorPosY() + (available.y - imageSize.y) * 0.5F);
    const ImVec2 imagePosition = ImGui::GetCursorScreenPos();
    ImGui::Image(ImTextureRef(static_cast<ImTextureID>(texture.id)), imageSize, {0, 0}, {1, 1});

    if (!device_.Connected()) {
        constexpr const char* message = "No video signal";
        const ImVec2 textSize = ImGui::CalcTextSize(message);
        const ImVec2 textPosition {
            imagePosition.x + (imageSize.x - textSize.x) * 0.5F,
            imagePosition.y + (imageSize.y - textSize.y) * 0.5F,
        };
        ImGui::GetWindowDrawList()->AddText(textPosition, IM_COL32(220, 220, 225, 255), message);
    }
    ImGui::EndChild();
}

void EmulatorApplication::DrawStatus()
{
    ImGui::SeparatorText("Device Status / Controls");
    ImGui::Text("Device: %s", device_.Connected() ? "Connected" : "Disconnected");
    ImGui::SameLine(230.0F);
    ImGui::Text("Transport: %.*s", static_cast<int>(transport_->Name().size()), transport_->Name().data());

    int mode = device_.Mode() == DeviceMode::BootDisplay ? 0 : 1;
    ImGui::SetNextItemWidth(180.0F);
    if (ImGui::Combo("Mode", &mode, "Boot Display\0OpenXR\0")) {
        device_.SetMode(mode == 0 ? DeviceMode::BootDisplay : DeviceMode::OpenXR);
    }

    const EyeImage& left = device_.Image(Eye::Left);
    const EyeImage& right = device_.Image(Eye::Right);
    ImGui::Text("Left Eye: %u x %u", left.width, left.height);
    ImGui::SameLine(230.0F);
    ImGui::Text("Right Eye: %u x %u", right.width, right.height);
    ImGui::Text("OpenXR: %s", device_.OpenXRSessionActive() ? "Active" : "Inactive");
    ImGui::SameLine(230.0F);
    ImGui::Text("Current mode: %s", ModeName(device_.Mode()));

    if (device_.Connected()) {
        ImGui::TextColored({0.35F, 1.0F, 0.45F, 1.0F}, "HEY, I'm a screen! Display to me!");
    } else {
        ImGui::TextDisabled("Waiting for the AR-OS VM display on 127.0.0.1:5901...");
    }
}

void DisconnectedTransport::Poll(EmulatedXRDevice&) { }
bool DisconnectedTransport::Connected() const noexcept { return false; }
std::string_view DisconnectedTransport::Name() const noexcept { return "None"; }

} // namespace AROS::DeviceEmulator

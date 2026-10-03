#include <AROS/DeviceEmulator/SandboxTransport.hpp>
#include <AROS/DeviceEmulator/EmulatedXRDevice.hpp>

#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>

#include <array>
#include <chrono>
#include <cstring>
#include <span>

namespace AROS::DeviceEmulator {
namespace {
using namespace std::chrono_literals;

bool ReceiveAll(int socket, std::span<std::uint8_t> bytes) {
    std::size_t received = 0;
    while (received < bytes.size()) {
        const auto count = recv(socket, bytes.data() + received,
                                bytes.size() - received, 0);
        if (count <= 0) return false;
        received += static_cast<std::size_t>(count);
    }
    return true;
}

std::uint32_t ReadU32(const std::uint8_t* bytes) {
    std::uint32_t value {};
    std::memcpy(&value, bytes, sizeof(value));
    return ntohl(value);
}
} // namespace

SandboxTransport::SandboxTransport()
    : rfb_(), worker_([this](std::stop_token token) { Run(token); }) {}

SandboxTransport::~SandboxTransport() {
    worker_.request_stop();
    const int socket = socket_.exchange(-1);
    if (socket >= 0) {
        shutdown(socket, SHUT_RDWR);
        close(socket);
    }
}

void SandboxTransport::Poll(EmulatedXRDevice& device) {
    rfb_.Poll(device);
    if (!xrConnected_.load()) {
        device.SetOpenXRSessionActive(false);
    }
    std::array<Frame, 2> frames;
    std::array<bool, 2> available {};
    {
        std::scoped_lock lock(mutex_);
        for (std::size_t eye = 0; eye < pending_.size(); ++eye) {
            if (pending_[eye].generation == consumedGeneration_[eye]) continue;
            frames[eye] = pending_[eye];
            consumedGeneration_[eye] = pending_[eye].generation;
            available[eye] = true;
        }
    }
    if (!available[0] && !available[1]) return;
    device.SetConnected(true);
    device.SetOpenXRSessionActive(true);
    for (std::size_t eye = 0; eye < frames.size(); ++eye)
        if (available[eye])
            device.SubmitEyeImage(eye == 0 ? Eye::Left : Eye::Right,
                                  frames[eye].width, frames[eye].height,
                                  frames[eye].pixels);
}

bool SandboxTransport::Connected() const noexcept {
    return xrConnected_.load() || rfb_.Connected();
}

std::string_view SandboxTransport::Name() const noexcept {
    return xrConnected_.load() ? "AR-OS stereo XR stream" : rfb_.Name();
}

void SandboxTransport::Run(const std::stop_token stopToken) {
    while (!stopToken.stop_requested()) {
        const int connection = ::socket(AF_INET, SOCK_STREAM, 0);
        if (connection < 0) {
            std::this_thread::sleep_for(500ms);
            continue;
        }
        socket_.store(connection);
        sockaddr_in address {};
        address.sin_family = AF_INET;
        address.sin_port = htons(4242);
        inet_pton(AF_INET, "127.0.0.1", &address.sin_addr);
        if (connect(connection, reinterpret_cast<sockaddr*>(&address),
                    sizeof(address)) != 0) {
            close(connection);
            socket_.store(-1);
            std::this_thread::sleep_for(500ms);
            continue;
        }
        xrConnected_.store(true);
        while (!stopToken.stop_requested()) {
            std::array<std::uint8_t, 20> header {};
            if (!ReceiveAll(connection, header) ||
                std::memcmp(header.data(), "ARXR", 4) != 0) break;
            Frame frame;
            frame.eye = header[4];
            frame.width = ReadU32(header.data() + 8);
            frame.height = ReadU32(header.data() + 12);
            const auto size = ReadU32(header.data() + 16);
            if (!frame.width || !frame.height ||
                size != static_cast<std::uint64_t>(frame.width) *
                            frame.height * 4U) break;
            frame.pixels.resize(size);
            if (!ReceiveAll(connection, frame.pixels)) break;
            std::scoped_lock lock(mutex_);
            frame.generation = nextGeneration_++;
            pending_[frame.eye == 0 ? 0 : 1] = std::move(frame);
        }
        xrConnected_.store(false);
        if (socket_.exchange(-1) == connection) close(connection);
    }
}

} // namespace AROS::DeviceEmulator

#include <AROS/DeviceEmulator/RfbTransport.hpp>

#include <AROS/DeviceEmulator/EmulatedXRDevice.hpp>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <array>
#include <chrono>
#include <cstring>
#include <iostream>
#include <span>
#include <stdexcept>
#include <thread>

namespace AROS::DeviceEmulator {
namespace {

using namespace std::chrono_literals;

void ReceiveAll(const int socket, const std::span<std::uint8_t> bytes)
{
    std::size_t received = 0;
    while (received < bytes.size()) {
        const auto result = recv(socket, bytes.data() + received, bytes.size() - received, 0);
        if (result <= 0) {
            throw std::runtime_error("RFB connection closed");
        }
        received += static_cast<std::size_t>(result);
    }
}

template<std::size_t Size>
std::array<std::uint8_t, Size> Receive(const int socket)
{
    std::array<std::uint8_t, Size> bytes {};
    ReceiveAll(socket, bytes);
    return bytes;
}

void SendAll(const int socket, const std::span<const std::uint8_t> bytes)
{
    std::size_t sent = 0;
    while (sent < bytes.size()) {
        const auto result = send(socket, bytes.data() + sent, bytes.size() - sent, MSG_NOSIGNAL);
        if (result <= 0) {
            throw std::runtime_error("failed to send RFB message");
        }
        sent += static_cast<std::size_t>(result);
    }
}

std::uint16_t ReadU16(const std::uint8_t* bytes)
{
    return static_cast<std::uint16_t>((static_cast<std::uint16_t>(bytes[0]) << 8U) | bytes[1]);
}

std::uint32_t ReadU32(const std::uint8_t* bytes)
{
    return (static_cast<std::uint32_t>(bytes[0]) << 24U)
        | (static_cast<std::uint32_t>(bytes[1]) << 16U)
        | (static_cast<std::uint32_t>(bytes[2]) << 8U)
        | bytes[3];
}

void WriteU16(std::uint8_t* bytes, const std::uint16_t value)
{
    bytes[0] = static_cast<std::uint8_t>(value >> 8U);
    bytes[1] = static_cast<std::uint8_t>(value);
}

void RequestFramebuffer(const int socket, const std::uint16_t width, const std::uint16_t height, const bool incremental)
{
    std::array<std::uint8_t, 10> request {3U, static_cast<std::uint8_t>(incremental), 0U, 0U, 0U, 0U};
    WriteU16(request.data() + 6, width);
    WriteU16(request.data() + 8, height);
    SendAll(socket, request);
}

void Skip(const int socket, const std::size_t size)
{
    std::array<std::uint8_t, 4096> scratch {};
    std::size_t remaining = size;
    while (remaining > 0U) {
        const auto chunk = std::min(remaining, scratch.size());
        ReceiveAll(socket, std::span(scratch).first(chunk));
        remaining -= chunk;
    }
}

} // namespace

RfbTransport::RfbTransport(std::string host, const std::uint16_t port)
    : host_(std::move(host))
    , port_(port)
    , name_("QEMU RFB " + host_ + ":" + std::to_string(port_))
    , worker_([this](const std::stop_token stopToken) { Run(stopToken); })
{
}

RfbTransport::~RfbTransport()
{
    worker_.request_stop();
    const int socket = socket_.exchange(-1);
    if (socket >= 0) {
        shutdown(socket, SHUT_RDWR);
        close(socket);
    }
}

void RfbTransport::Poll(EmulatedXRDevice& device)
{
    std::scoped_lock lock(frameMutex_);
    if (pendingGeneration_ == consumedGeneration_) {
        return;
    }
    device.SubmitBootImage(pendingWidth_, pendingHeight_, pendingFrame_);
    consumedGeneration_ = pendingGeneration_;
}

bool RfbTransport::Connected() const noexcept { return connected_.load(); }
std::string_view RfbTransport::Name() const noexcept { return name_; }

void RfbTransport::Run(const std::stop_token stopToken)
{
    while (!stopToken.stop_requested()) {
        const int connection = ::socket(AF_INET, SOCK_STREAM, 0);
        if (connection < 0) {
            std::this_thread::sleep_for(1s);
            continue;
        }
        socket_.store(connection);

        sockaddr_in address {};
        address.sin_family = AF_INET;
        address.sin_port = htons(port_);
        if (inet_pton(AF_INET, host_.c_str(), &address.sin_addr) != 1
            || connect(connection, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0) {
            close(connection);
            socket_.store(-1);
            std::this_thread::sleep_for(500ms);
            continue;
        }

        try {
            RunConnection(connection, stopToken);
        } catch (const std::exception& error) {
            if (!stopToken.stop_requested()) {
                std::cerr << "Device Emulator RFB: " << error.what() << '\n';
            }
        }
        connected_.store(false);
        if (socket_.exchange(-1) == connection) {
            close(connection);
        }
        std::this_thread::sleep_for(500ms);
    }
}

void RfbTransport::RunConnection(const int socket, const std::stop_token stopToken)
{
    const auto serverVersion = Receive<12>(socket);
    if (std::memcmp(serverVersion.data(), "RFB ", 4) != 0) {
        throw std::runtime_error("invalid RFB server greeting");
    }
    constexpr std::array<std::uint8_t, 12> clientVersion {'R','F','B',' ','0','0','3','.','0','0','8','\n'};
    SendAll(socket, clientVersion);

    const auto securityCount = Receive<1>(socket)[0];
    if (securityCount == 0U) {
        throw std::runtime_error("RFB server rejected the connection");
    }
    std::vector<std::uint8_t> securityTypes(securityCount);
    ReceiveAll(socket, securityTypes);
    if (std::find(securityTypes.begin(), securityTypes.end(), 1U) == securityTypes.end()) {
        throw std::runtime_error("QEMU RFB does not offer unauthenticated local access");
    }
    constexpr std::array<std::uint8_t, 1> noAuthentication {1U};
    SendAll(socket, noAuthentication);
    if (ReadU32(Receive<4>(socket).data()) != 0U) {
        throw std::runtime_error("RFB security handshake failed");
    }

    constexpr std::array<std::uint8_t, 1> sharedSession {1U};
    SendAll(socket, sharedSession);
    const auto serverInit = Receive<24>(socket);
    std::uint16_t width = ReadU16(serverInit.data());
    std::uint16_t height = ReadU16(serverInit.data() + 2);
    Skip(socket, ReadU32(serverInit.data() + 20));

    std::array<std::uint8_t, 20> pixelFormat {
        0U, 0U, 0U, 0U,
        32U, 24U, 0U, 1U,
        0U, 255U, 0U, 255U, 0U, 255U,
        16U, 8U, 0U, 0U, 0U, 0U,
    };
    SendAll(socket, pixelFormat);
    constexpr std::array<std::uint8_t, 8> rawEncoding {2U, 0U, 0U, 1U, 0U, 0U, 0U, 0U};
    SendAll(socket, rawEncoding);

    std::vector<std::uint8_t> framebuffer(static_cast<std::size_t>(width) * height * 4U, 0U);
    RequestFramebuffer(socket, width, height, false);
    connected_.store(true);
    std::cout << "Device Emulator RFB: connected to AR-OS display ("
              << width << 'x' << height << ')' << std::endl;
    bool reportedFirstFrame = false;

    while (!stopToken.stop_requested()) {
        const std::uint8_t messageType = Receive<1>(socket)[0];
        if (messageType == 0U) {
            const auto updateHeader = Receive<3>(socket);
            const auto rectangleCount = ReadU16(updateHeader.data() + 1);
            for (std::uint16_t rectangle = 0; rectangle < rectangleCount; ++rectangle) {
                const auto rectangleHeader = Receive<12>(socket);
                const auto x = ReadU16(rectangleHeader.data());
                const auto y = ReadU16(rectangleHeader.data() + 2);
                const auto rectangleWidth = ReadU16(rectangleHeader.data() + 4);
                const auto rectangleHeight = ReadU16(rectangleHeader.data() + 6);
                const auto encoding = static_cast<std::int32_t>(ReadU32(rectangleHeader.data() + 8));
                if (encoding != 0) {
                    throw std::runtime_error("QEMU sent an unsupported RFB encoding");
                }

                std::vector<std::uint8_t> pixels(
                    static_cast<std::size_t>(rectangleWidth) * rectangleHeight * 4U);
                ReceiveAll(socket, pixels);
                for (std::uint16_t row = 0; row < rectangleHeight; ++row) {
                    for (std::uint16_t column = 0; column < rectangleWidth; ++column) {
                        const auto source = (static_cast<std::size_t>(row) * rectangleWidth + column) * 4U;
                        const auto destination =
                            (static_cast<std::size_t>(y + row) * width + x + column) * 4U;
                        framebuffer[destination + 0U] = pixels[source + 2U];
                        framebuffer[destination + 1U] = pixels[source + 1U];
                        framebuffer[destination + 2U] = pixels[source + 0U];
                        framebuffer[destination + 3U] = 255U;
                    }
                }
            }

            {
                std::scoped_lock lock(frameMutex_);
                pendingFrame_ = framebuffer;
                pendingWidth_ = width;
                pendingHeight_ = height;
                ++pendingGeneration_;
            }
            RequestFramebuffer(socket, width, height, true);
            if (!reportedFirstFrame) {
                std::cout << "Device Emulator RFB: received first boot framebuffer" << std::endl;
                reportedFirstFrame = true;
            }
        } else if (messageType == 2U) {
            // Bell has no payload.
        } else if (messageType == 3U) {
            const auto header = Receive<7>(socket);
            Skip(socket, ReadU32(header.data() + 3));
        } else {
            throw std::runtime_error("QEMU sent an unsupported RFB server message");
        }
    }
}

} // namespace AROS::DeviceEmulator

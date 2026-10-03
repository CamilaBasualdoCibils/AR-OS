#pragma once
#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
namespace AROS::VirtualDisplay {
struct Frame { std::vector<std::uint8_t> rgba; std::uint32_t width{}; std::uint32_t height{}; std::uint64_t generation{}; };
class RfbClient final {
public:
 explicit RfbClient(std::string host="127.0.0.1",std::uint16_t port=5901,std::string logPrefix="Virtual display");
 ~RfbClient(); RfbClient(const RfbClient&)=delete; RfbClient& operator=(const RfbClient&)=delete;
 [[nodiscard]] bool Poll(Frame&); [[nodiscard]] bool Connected()const noexcept{return connected_.load();}
 [[nodiscard]] const std::string& Endpoint()const noexcept{return endpoint_;}
private:
 void Run(std::stop_token); void RunConnection(int,std::stop_token);
 std::string host_; std::uint16_t port_; std::string endpoint_; std::string logPrefix_; std::jthread worker_;
 std::atomic_bool connected_{false}; std::atomic_int socket_{-1}; std::mutex frameMutex_; std::vector<std::uint8_t> pendingFrame_; std::uint32_t pendingWidth_{}; std::uint32_t pendingHeight_{}; std::uint64_t pendingGeneration_{}; std::uint64_t consumedGeneration_{};
};
}

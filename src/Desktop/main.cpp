#include "ARUI/Core/Debug/AllowDebugger.hpp"
#include "Manager.hpp"
#include "SystemExperience.hpp"

#include <chrono>
#include <csignal>
#include <exception>
#include <iostream>
#include <thread>

namespace {
volatile std::sig_atomic_t running = 1;
void Stop(int) { running = 0; }
} // namespace

int main() {
  ARUI::Debug::AllowConfiguredDebuggerAttach();
  try {
    std::signal(SIGINT, Stop);
    std::signal(SIGTERM, Stop);
    auto presentation = AROS::ConnectPresentationController();
    AROS::ShowSystemExperience(*presentation, "AR-OS Desktop");
    AROS::Desktop::Manager manager;
    manager.Start();
    while (running)
      std::this_thread::sleep_for(std::chrono::seconds{1});
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "arui-desktop: " << error.what() << '\n';
    return 1;
  }
}

#include "ARUI/Core/Debug/AllowDebugger.hpp"
#include "SystemExperience.hpp"

#include <exception>
#include <iostream>

int main() {
  ARUI::Debug::AllowConfiguredDebuggerAttach();
  try {
    auto presentation = AROS::ConnectPresentationController();
    AROS::ShowSystemExperience(*presentation, "AR-OS Login");
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "arui-login: " << error.what() << '\n';
    return 1;
  }
}

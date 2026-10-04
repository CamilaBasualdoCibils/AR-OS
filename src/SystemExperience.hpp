#pragma once

#include "ARUI/Language/node.hpp"
#include "ARUI/Presentation/IPresentationController.hpp"
#include "ARUI/Presentation/RpcPresentationController.hpp"

#include <cstdlib>
#include <memory>
#include <spdlog/spdlog.h>
#include <string>

namespace AROS {
inline std::unique_ptr<ARUI::Presentation::IPresentationController>
ConnectPresentationController() {
  const char *host = std::getenv("ARUI_PRESENTATION_HOST");
  const char *portEnv = std::getenv("ARUI_PRESENTATION_PORT");
  if (!host) {
    host = "127.0.0.1";
  }
  const auto port = portEnv
                        ? static_cast<std::uint16_t>(std::stoi(portEnv))
                        : ARUI::Presentation::DefaultPresentationPort;
  spdlog::info("Connecting to presentation controller at {}:{}", host, port);
  return std::make_unique<ARUI::Presentation::RpcPresentationController>(
      host, port);
}

inline void ShowSystemExperience(ARUI::Presentation::IPresentationController &controller,
                                 std::string label) {
  using namespace ARUI::Language;
  Style style;
  style.width = {1.0, LengthUnit::Meter};
  style.height = {0.75, LengthUnit::Meter};
  style.zOffset = {-2.0, LengthUnit::Meter};
  controller.SetActiveTree(LSurface({LText(std::move(label))}, {}, std::move(style)));
}
} // namespace AROS

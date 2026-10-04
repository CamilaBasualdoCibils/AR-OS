#pragma once

#include "ARUI/Language/node.hpp"
#include "ARUI/Presentation/IPresentationController.hpp"
#include "ARUI/Presentation/RpcPresentationController.hpp"

#include <cstdlib>
#include <memory>
#include <string>

namespace AROS {
inline std::unique_ptr<ARUI::Presentation::IPresentationController>
ConnectPresentationController() {
  const char *host = std::getenv("ARUI_PRESENTATION_HOST");
  const char *port = std::getenv("ARUI_PRESENTATION_PORT");
  return std::make_unique<ARUI::Presentation::RpcPresentationController>(
      host ? host : "127.0.0.1",
      port ? static_cast<std::uint16_t>(std::stoi(port))
           : ARUI::Presentation::DefaultPresentationPort);
}

inline ARUI::Presentation::PresentationNodeID
ShowSystemExperience(ARUI::Presentation::IPresentationController &controller,
                     std::string label) {
  using namespace ARUI::Language;
  Style style;
  style.width = {1.0, LengthUnit::Meter};
  style.height = {0.75, LengthUnit::Meter};
  style.zOffset = {-2.0, LengthUnit::Meter};
  controller.Reset();
  return controller.CreateTree(
      ARUI::Presentation::PresentationRoot,
      LSurface({LText(std::move(label))}, {}, std::move(style)));
}
} // namespace AROS

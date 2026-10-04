#include "VISR/Core/Debug/AllowDebugger.hpp"
#include "VISR/Language/AttributeValue.hpp"
#include "VISR/Language/Color.hpp"
#include "VISR/Language/Style.hpp"
#include "VISR/Language/node.hpp"
#include "SystemExperience.hpp"

#include <exception>
#include <iostream>
#include <spdlog/spdlog.h>

int main() {
  using namespace VISR;
  using namespace VISR::Language;
  VISR::Debug::AllowConfiguredDebuggerAttach();
  try {
    spdlog::info("Starting VISR OS Boot");
    auto presentation = VISROS::ConnectPresentationController();
    spdlog::info("Connected");

    LNode text = LText("Hello, VISR OS!", TextOptions{},
                       Style{.fontSize = Length{15, LengthUnit::Centimeter}});
    LNode panel = LPanel(
        {text}, PanelOptions{},
        Style{.painter = PainterReference{"default"},
              .painterProperties = {
                  {"fill",
                   PainterStyleValue{Color{.rgba = {255, 255, 255, 255}}}}}});
    LNode surface = LSurface(
        {panel},
        SurfaceOptions{.anchor = "head", .surfaceType = SurfaceType::Plane},
        Style{.width = {30, LengthUnit::Centimeter},
              .height = {20, LengthUnit::Centimeter},
              .zOffset = Length{-50, LengthUnit::Centimeter}});
    presentation->SetActiveTree(surface);

    return 0;
  } catch (const std::exception &error) {
    spdlog::critical("visr-boot: {}", error.what());
    return 1;
  }
}

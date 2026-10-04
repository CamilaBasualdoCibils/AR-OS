#include "ARUI/Core/Debug/AllowDebugger.hpp"
#include "ARUI/Language/AttributeValue.hpp"
#include "ARUI/Language/Color.hpp"
#include "ARUI/Language/Style.hpp"
#include "ARUI/Language/node.hpp"
#include "SystemExperience.hpp"

#include <exception>
#include <iostream>
#include <spdlog/spdlog.h>

int main() {
  using namespace ARUI;
  using namespace ARUI::Language;
  ARUI::Debug::AllowConfiguredDebuggerAttach();
  try {
    spdlog::info("Starting AR-OS Boot");
    auto presentation = AROS::ConnectPresentationController();
    spdlog::info("Connected");

    LNode text = LText("Hello, AR-OS!", TextOptions{},
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
    spdlog::critical("arui-boot: {}", error.what());
    return 1;
  }
}

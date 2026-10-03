#include "ARUI/Core/Debug/AllowDebugger.hpp"
#include "ARUI/Render/Backends/OpenGL/OpenGLRenderDevice.hpp"
#include "ARUI/Render/Backends/OpenGL/OpenGLOpenXRBinding.hpp"
#include "ARUI/XR/OpenXR/OpenXRPresenter.hpp"

#include <memory>

int main() {
  ARUI::Debug::AllowConfiguredDebuggerAttach();
  auto renderDevice = std::make_shared<ARUI::Render::OpenGLRenderDevice>();
  auto graphics =
      std::make_shared<ARUI::Render::OpenGLOpenXRBinding>(renderDevice);
  auto presenter =
      std::make_shared<ARUI::OpenXR::OpenXRPresenter>(graphics);
  presenter->BeginFrame();
  presenter->EndFrame();
  return 0;
}

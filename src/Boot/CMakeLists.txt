add_executable(AruiBoot main.cpp)
target_link_libraries(AruiBoot PRIVATE
    ARUI::RenderOpenGL
    ARUI::OpenXR
    ARUI::RenderOpenGLOpenXR)
arui_enable_runtime_instrumentation(AruiBoot)

add_executable(AruiDesktop main.cpp Manager.cpp)
target_include_directories(AruiDesktop PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_link_libraries(AruiDesktop PRIVATE ARUI::Core ARUI::Presentation)
arui_enable_runtime_instrumentation(AruiDesktop)

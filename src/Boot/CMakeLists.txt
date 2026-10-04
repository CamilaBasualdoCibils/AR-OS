add_executable(AruiBoot main.cpp)
target_include_directories(AruiBoot PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_link_libraries(AruiBoot PRIVATE ARUI::Core ARUI::Presentation)
arui_enable_runtime_instrumentation(AruiBoot)

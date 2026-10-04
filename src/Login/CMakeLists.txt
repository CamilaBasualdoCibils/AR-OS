add_executable(AruiLogin main.cpp)
target_include_directories(AruiLogin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_link_libraries(AruiLogin PRIVATE ARUI::Core ARUI::Presentation)
arui_enable_runtime_instrumentation(AruiLogin)

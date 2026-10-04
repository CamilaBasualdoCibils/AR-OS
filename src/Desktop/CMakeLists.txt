add_executable(VisrDesktop main.cpp Manager.cpp)
target_include_directories(VisrDesktop PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_link_libraries(VisrDesktop PRIVATE VISR::Core VISR::Presentation)
visr_enable_runtime_instrumentation(VisrDesktop)

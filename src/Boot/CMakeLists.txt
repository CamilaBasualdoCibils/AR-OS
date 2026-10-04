add_executable(VisrBoot main.cpp)
target_include_directories(VisrBoot PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_link_libraries(VisrBoot PRIVATE VISR::Core VISR::Presentation)
visr_enable_runtime_instrumentation(VisrBoot)

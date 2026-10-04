add_executable(VisrLogin main.cpp)
target_include_directories(VisrLogin PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)
target_link_libraries(VisrLogin PRIVATE VISR::Core VISR::Presentation)
visr_enable_runtime_instrumentation(VisrLogin)

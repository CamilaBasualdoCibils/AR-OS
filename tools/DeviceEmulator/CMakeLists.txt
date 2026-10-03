find_package(glfw3 CONFIG REQUIRED)
find_package(imgui CONFIG REQUIRED)
find_package(OpenGL REQUIRED)

add_executable(
    AROSDeviceEmulator
    src/main.cpp
    src/EmulatedXRDevice.cpp
    src/EmulatorApplication.cpp
    src/RfbTransport.cpp
)

target_compile_features(AROSDeviceEmulator PRIVATE cxx_std_23)
target_include_directories(
    AROSDeviceEmulator
    PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
)
target_link_libraries(
    AROSDeviceEmulator
    PRIVATE
        glfw
        imgui::imgui
        OpenGL::GL
)

set_target_properties(AROSDeviceEmulator PROPERTIES OUTPUT_NAME ar-os-device-emulator)

install(TARGETS AROSDeviceEmulator RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

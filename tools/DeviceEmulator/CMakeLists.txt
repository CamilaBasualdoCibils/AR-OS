find_package(glfw3 CONFIG REQUIRED)
find_package(imgui CONFIG REQUIRED)
find_package(OpenGL REQUIRED)

add_executable(
    VISROSDeviceEmulator
    src/main.cpp
    src/EmulatedXRDevice.cpp
    src/EmulatorApplication.cpp
    src/RfbTransport.cpp
    src/SandboxTransport.cpp
)

target_compile_features(VISROSDeviceEmulator PRIVATE cxx_std_23)
target_include_directories(
    VISROSDeviceEmulator
    PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/include"
        "${CMAKE_CURRENT_SOURCE_DIR}/src"
)
target_link_libraries(
    VISROSDeviceEmulator
    PRIVATE
        glfw
        imgui::imgui
        OpenGL::GL
        VISROSVirtualDisplay
)

set_target_properties(VISROSDeviceEmulator PROPERTIES OUTPUT_NAME visr-os-device-emulator)

install(TARGETS VISROSDeviceEmulator RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

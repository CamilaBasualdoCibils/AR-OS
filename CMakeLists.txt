cmake_minimum_required(VERSION 3.25)

project(
    AROS
    VERSION 0.1.0
    LANGUAGES C CXX
)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(AROS_BUILD_DEVICE_EMULATOR "Build the VM/development XR device emulator" ON)
option(AROS_BUILD_XR_DISPLAY_BRIDGE "Build the host OpenXR virtual-display bridge" ON)

include(GNUInstallDirs)

add_subdirectory(src)
add_subdirectory(tools)

add_custom_target(
    build-vm
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/build-vm.sh"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Building the AR-OS NixOS VM"
    USES_TERMINAL
)

add_custom_target(
    run-vm
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/run-vm.sh"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Running the AR-OS VM with QEMU/KVM"
    USES_TERMINAL
)

add_dependencies(run-vm build-vm)

if(AROS_BUILD_XR_DISPLAY_BRIDGE)
add_custom_target(
    run-xr-display
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/run-xr-display.sh"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Running the AR-OS XR Display Bridge"
    USES_TERMINAL
)
add_dependencies(run-xr-display AROSXRDisplayBridge)
endif()

add_custom_target(
    build-vm-debug
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/build-vm.sh" --debug
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Building the AR-OS NixOS VM in debug mode"
    USES_TERMINAL
)

add_custom_target(
    run-vm-debug
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/run-vm.sh" --debug
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Running the AR-OS VM with debug display and tmux console"
    USES_TERMINAL
)
add_dependencies(run-vm-debug build-vm-debug)

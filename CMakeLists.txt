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

add_subdirectory(AR-UI)
add_subdirectory(src)
add_subdirectory(tools)

add_custom_target(
    build-vm
    COMMAND "${CMAKE_COMMAND}" -E env "AROS_ARUI_DESKTOP=$<TARGET_FILE:AruiDesktop>" "AROS_ARUI_LOGIN=$<TARGET_FILE:AruiLogin>" "AROS_ARUI_BOOT=$<TARGET_FILE:AruiBoot>" "${CMAKE_SOURCE_DIR}/scripts/build-vm.sh"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Building the AR-OS NixOS VM"
    USES_TERMINAL
    VERBATIM
)

add_custom_target(
    run-vm
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/run-vm.sh"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Running the AR-OS VM with QEMU/KVM"
    USES_TERMINAL
    VERBATIM
)

add_dependencies(build-vm AruiBoot AruiLogin AruiDesktop)
add_dependencies(run-vm build-vm)

if(AROS_BUILD_XR_DISPLAY_BRIDGE)
add_custom_target(
    run-xr-display
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/run-xr-display.sh"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Running the AR-OS XR Display Bridge"
    USES_TERMINAL
    VERBATIM
)
add_dependencies(run-xr-display AROSXRDisplayBridge)
endif()

add_custom_target(
    build-vm-debug
    COMMAND "${CMAKE_COMMAND}" -E env "AROS_ARUI_DESKTOP=$<TARGET_FILE:AruiDesktop>" "AROS_ARUI_LOGIN=$<TARGET_FILE:AruiLogin>" "AROS_ARUI_BOOT=$<TARGET_FILE:AruiBoot>" "${CMAKE_SOURCE_DIR}/scripts/build-vm.sh" --debug
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Building the AR-OS NixOS VM in debug mode"
    USES_TERMINAL
    VERBATIM
)

add_custom_target(
    run-vm-debug
    COMMAND "${CMAKE_SOURCE_DIR}/scripts/run-vm.sh" --debug
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    COMMENT "Running the AR-OS VM with debug display and tmux console"
    USES_TERMINAL
    VERBATIM
)
add_dependencies(build-vm-debug AruiBoot AruiLogin AruiDesktop)
add_dependencies(run-vm-debug build-vm-debug)

# Keep the complete target graph readable in CMake-aware IDEs and CMake Tools.
# Assign after all subdirectories so targets created indirectly (tests, shaders,
# FrameGraph, and custom VM commands) are covered as well.
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

function(aros_assign_target_folders directory)
    string(FIND "${directory}" "${CMAKE_SOURCE_DIR}/AR-UI" arui_prefix)
    if(arui_prefix EQUAL 0)
        set(folder "AR-UI")
    else()
        set(folder "AR-OS")
    endif()

    get_property(directory_targets DIRECTORY "${directory}" PROPERTY BUILDSYSTEM_TARGETS)
    foreach(target IN LISTS directory_targets)
        set_property(TARGET "${target}" PROPERTY FOLDER "${folder}")
    endforeach()

    get_property(subdirectories DIRECTORY "${directory}" PROPERTY SUBDIRECTORIES)
    foreach(subdirectory IN LISTS subdirectories)
        aros_assign_target_folders("${subdirectory}")
    endforeach()
endfunction()

aros_assign_target_folders("${CMAKE_SOURCE_DIR}")

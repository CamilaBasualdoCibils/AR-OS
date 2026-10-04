add_subdirectory(VirtualDisplay)

if(VISROS_BUILD_DEVICE_EMULATOR)
    add_subdirectory(DeviceEmulator)
endif()

if(VISROS_BUILD_XR_DISPLAY_BRIDGE)
    add_subdirectory(XRDisplayBridge)
endif()

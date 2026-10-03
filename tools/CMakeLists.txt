add_subdirectory(VirtualDisplay)

if(AROS_BUILD_DEVICE_EMULATOR)
    add_subdirectory(DeviceEmulator)
endif()

if(AROS_BUILD_XR_DISPLAY_BRIDGE)
    add_subdirectory(XRDisplayBridge)
endif()

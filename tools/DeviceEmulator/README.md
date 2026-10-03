# AR-OS Device Emulator

The Device Emulator is a host-side GLFW, Dear ImGui, and OpenGL application
that visualizes fake XR hardware for an AR-OS VM. It is separate from the ARUI
Simulator: the latter tests ARUI itself, while this tool models hardware below
AR-OS/OpenXR. It does not include or link any ARUI code.

```text
                    AR-OS VM
                       │
          ┌────────────┴────────────┐
          │                         │
     Boot Display               OpenXR
          │                         │
          └────────────┬────────────┘
                       │
                Device Transport
                       │
════════════════════ VM boundary ═══════════════════
                       │
                Device Emulator
                       │
              EmulatedXRDevice
                       │
                GLFW + ImGui
                  │       │
                  ▼       ▼
               Left     Right
                Eye      Eye
```

`BootDisplay` accepts one RGBA8 image and copies it into distinct left-eye and
right-eye state, producing a simple mirrored boot display. `OpenXR` mode keeps
the eyes independent for a future runtime/driver. The UI consumes device state;
it is not an ARUI rendering backend.

The initial boot-display transport uses QEMU's standard local VNC/RFB display
endpoint. Linux sees a normal `virtio-vga` screen; QEMU publishes its framebuffer
on loopback port 5901; and the emulator consumes raw framebuffer updates and
mirrors them into both eyes. When no VM is present the emulator remains open and
shows two separate "No video signal" textures. The RFB implementation is only
the boot-display transport, not the future OpenXR device protocol.

## Build and run

Dependencies come from the root vcpkg manifest:

```bash
cmake --preset vcpkg-preset
cmake --build build --target AROSDeviceEmulator
./scripts/run-device-emulator.sh
```

Current functionality includes host visualization, QEMU boot-framebuffer
capture, mirrored boot output, independent eye-image state, mode selection, and
a transport boundary. It does not implement an OpenXR runtime, tracking, hands,
controllers, or an XR device protocol.

# VISR OS Device Emulator

The Device Emulator is a host-side GLFW, Dear ImGui, and OpenGL application
that visualizes fake XR hardware for a VISR OS VM. It is separate from the VISR
Simulator: the latter tests VISR itself, while this tool models hardware below
VISR OS/OpenXR. It does not include or link any VISR code.

```text
                    VISR OS VM
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
right-eye state, producing a simple mirrored boot display. Once VISR Desktop
creates its Monado OpenXR session, the Sandbox transport switches to independent
left/right RGBA8 eye frames. The UI consumes device state;
it is not a VISR rendering backend.

The initial boot-display transport uses QEMU's standard local VNC/RFB display
endpoint. Linux sees a normal `virtio-vga` screen; QEMU publishes its framebuffer
on loopback port 5901; and the emulator consumes raw framebuffer updates and
mirrors them into both eyes. When no VM is present the emulator remains open and
shows two separate "No video signal" textures. RFB remains the early boot
transport. QEMU also forwards loopback port 4245 to VISR Server's raw stereo
publisher; the combined Sandbox transport automatically switches the emulator
to OpenXR mode when those frames arrive.

## Build and run

Dependencies come from the root vcpkg manifest:

```bash
cmake --preset vcpkg-preset
cmake --build build --target VISROSDeviceEmulator
./scripts/run-device-emulator.sh
```

Current functionality includes host visualization, QEMU boot-framebuffer
capture, mirrored boot output, a working Monado OpenXR session in the guest,
and independent streamed eye images. The emulator drives Monado's built-in remote HMD over a dedicated forwarded port: its Fake HMD Tracking controls set the 6DoF head pose and IPD in the guest runtime. Hand and controller input are not sent.

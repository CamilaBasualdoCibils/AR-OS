# XR Display Bridge

The visr-os-xr-display program is a host OpenXR application that presents the VISR OS VM's ordinary virtual display as a readable, head-relative monitor. It is infrastructure below VISR: neither VISR OS nor VISR needs WiVRn, Quest-specific software, or OpenXR for boot output.

## Architecture

                             BOOT PATH

                    ┌──────────────┐
                    │   VISR OS VM   │
                    │              │
                    │ Linux Console│
                    └──────┬───────┘
                           │
                    Virtual Display
                           │
═══════════════════════════╪════════════════════════════
                           │
                    XR Display Bridge
                           │
                         OpenXR
                           │
                         WiVRn
                           │
                           ▼
                        Quest 2

Linux sees QEMU's virtio-vga through the normal DRM/framebuffer/console path. QEMU remains headless and publishes that display on loopback RFB port 5901. VISROSVirtualDisplay receives RGBA frames and desktop-size changes. The bridge uploads each received frame to an OpenGL OpenXR swapchain and submits an XrCompositionLayerQuad in VIEW space, centered 1.5 metres ahead. Its physical height follows the framebuffer aspect ratio.

The Device Emulator remains a separate GLFW/ImGui fake-device application. Both programs use VISROSVirtualDisplay; QEMU permits shared RFB clients, so either or both consumers may run.

## Build and run with Quest 2

The OpenXR loader is supplied by the root vcpkg manifest:

    cmake --preset vcpkg-preset
    cmake --build build --target VISROSXRDisplayBridge
    ./scripts/build-vm.sh

Install and start WiVRn on the host, make WiVRn the active OpenXR runtime, and connect the Quest 2. Runtime setup belongs to WiVRn; the bridge contains no WiVRn-specific API calls. Then use separate terminals in this order:

    ./scripts/run-xr-display.sh
    ./scripts/run-sandbox.sh
    # Optional, concurrently:
    ./scripts/run-device-emulator.sh

The bridge may start before the VM and waits for RFB at 127.0.0.1:5901. It reconnects after VM/display disconnection. Starting the VM first also works. The CMake target run-xr-display builds and launches the bridge.

## Diagnostics

- A runtime-loading or instance-creation error means no active host OpenXR runtime was found. With WiVRn, verify its runtime JSON is selected; XR_RUNTIME_JSON can select it for one shell.
- “No headset is connected” means the runtime is active but no HMD system is available. Start the WiVRn server and connect its Quest 2 client, then retry.
- An XR_KHR_opengl_enable error means the selected runtime cannot accept the bridge's OpenGL binding.
- A GLFW/X11 context error means the bridge was not run from a host graphical X11 session. Its window is hidden; QEMU itself still has no GTK/SDL display.
- “Waiting for VISR OS framebuffer” means the VM is not publishing RFB yet. Start scripts/run-sandbox.sh and confirm its VNC port remains 5901.
- The bridge ends an OpenXR session cleanly on STOPPING and begins it again if the runtime returns to READY. Runtime loss exits with a useful diagnostic so the process can be restarted.
- Serial fallback remains in .vm/serial.log; SSH remains ssh -p 2222 aros@127.0.0.1.

## Future VISR handoff

This task does not implement an OpenXR runtime or proxy inside the VM. The intended later path is:

                       FUTURE VISR PATH

                    ┌──────────────┐
                    │   VISR OS VM   │
                    │              │
                    │     VISR     │
                    │      │       │
                    │    OpenXR    │
                    └──────┬───────┘
                           │
                    OpenXR Proxy
                           │
═══════════════════════════╪════════════════════════════
                           │
                     Host XR Bridge
                           │
                         OpenXR
                           │
                         WiVRn
                           │
                           ▼
                        Quest 2

At power-on the virtual display is active immediately and carries the Linux console through this bridge. Later, a VISR OS virtual OpenXR runtime may proxy VISR to the host bridge. At that handoff the boot monitor could disappear, remain a debug monitor, or become a VISR system console; this implementation intentionally chooses none of those policies. VISR continues to know only OpenXR, and the unrelated VISR Simulator is neither linked nor launched.

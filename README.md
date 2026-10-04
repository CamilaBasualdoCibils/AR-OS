# AR-OS

AR-OS is the build and operating-system integration repository for a standalone,
Linux-based spatial environment centered on ARUI.

```text
Linux / NixOS
      ↓
    AR-OS
      ↓
     ARUI
      ↓
Spatial Applications
```

Nix constructs the operating system in two layers. **Base** is
hardware-independent AR-OS; **Sandbox** imports Base and adds QEMU, developer
access, host display integration, and streaming tools. The root CMake project
builds native AR-OS tools and the ARUI subproject. The ARUI-owned `AruiServer`
and the AR-OS-owned `AruiBoot`, `AruiLogin`, and `AruiDesktop` artifacts are
patched and bundled into the NixOS closure during every VM build.

## Device backends

The shared OS is intended to support QEMU, desktop OpenXR runtimes, development
boards, and physical glasses. Backend-specific software stays out of shared
configuration. The host-side `AROSDeviceEmulator` mirrors the VM display as fake XR hardware.
The separate XR Display Bridge presents that display through the active host
OpenXR runtime. Neither host tool is installed in the minimal OS image.

The two similarly named development tools are deliberately unrelated:

```text
ARUI Simulator            AR-OS Device Emulator
= tests ARUI itself       = represents virtual XR hardware
= ARUI-local tool         = AR-OS VM/development tool
= not part of AR-OS       = excluded from production by default
```

AR-OS does not launch the standalone ARUI Simulator. `AruiServer` owns the
runtime, renderer, and OpenXR session; AR-OS system experiences control its
presentation through the privileged loopback RPC service. The Device Emulator
and XR Display Bridge remain unrelated host tools.

## Checkout and prerequisites

Clone with the submodule:

```bash
git clone --recursive <repo>
cd AR-OS
```

For an existing checkout:

```bash
git submodule update --init --recursive
```

Install Nix with flakes enabled, and ensure QEMU/KVM and `/dev/kvm` access are
available. Native CMake development additionally requires CMake 3.25+, Ninja,
a C++23 compiler, and vcpkg. External CMake dependencies are declared in each
project's `vcpkg.json`; do not install or resolve them ad hoc from the host.

## Native build

The root project owns `src/`, `tools/`, and adds the ARUI submodule as a CMake
dependency so the OS image always receives the matching ARUI system builds.

```bash
vcpkg install
cmake -S . -B build -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" \
  -DAROS_BUILD_DEVICE_EMULATOR=ON
cmake --build build
```

If `VCPKG_ROOT` is not set, replace it with the path to the vcpkg checkout.
Manifest mode supplies GLFW and Dear ImGui to the emulator target. ARUI keeps
its own independent `AR-UI/vcpkg.json` manifest.

Use `-DAROS_BUILD_DEVICE_EMULATOR=OFF` for a production-oriented native build.
The emulator links GLFW and Dear ImGui and consumes the shared RFB virtual-display
transport.

## Base and Sandbox

```text
AR-OS Base
├── Linux/NixOS, networking and graphics
├── ARUI boot, login and desktop services
└── Monado/OpenXR
        │
        └── Sandbox
            ├── QEMU/virtio/virgl
            ├── SSH, gdb and tmux
            ├── GStreamer
            └── loopback RFB → Device Emulator / XR Display Bridge
```

Base has no dependency on QEMU, Device Emulator, XRDisplayBridge, or remote
display infrastructure. It is the parent for future Deck X and other hardware
configurations. Sandbox owns all current development-VM behavior. GStreamer and
its base/good/bad plugin sets are installed only in Sandbox; the streaming
layer is separate from ARUI. The initial raw stream remains QEMU's shared RFB
endpoint so the two existing host consumers keep working while a future
GStreamer producer can be connected to framebuffer or Monado frames.

Build either output directly (the helper scripts supply the ARUI executables):

```bash
nix build 'path:.#base'
nix build 'path:.#sandbox'
QEMU_OPTS=-enable-kvm ./result-sandbox/bin/run-ar-os-vm
```

The root CMake project exposes convenience targets for the normal development
workflow. `run-vm` depends on `build-sandbox`, checks `/dev/kvm`, and explicitly
enables KVM acceleration:

```bash
cmake --build build --target build-base
cmake --build build --target build-sandbox
cmake --build build --target run-vm
```

The equivalent scripts are:

```bash
./scripts/build-base.sh
./scripts/build-vm.sh
./scripts/run-device-emulator.sh
./scripts/run-sandbox.sh
```

All writable VM state is kept under `.vm/`:

```text
.vm/
├── ar-os-sandbox.qcow2 # persistent Sandbox root filesystem
├── serial.log     # secondary serial-console diagnostics
├── shared/       # persistent host/guest exchange directory
```

The immutable kernel, initrd, and NixOS closure remain in `/nix/store`; they are
build outputs rather than VM runtime state.
Per-run sockets are created under the host temporary directory and removed when
the Sandbox exits, keeping special files out of the path-flake source tree.

The graphical `tty0` console is the primary boot console and is carried to the
Device Emulator through QEMU's loopback RFB display. The secondary `ttyS0`
console is retained in `.vm/serial.log`; it is not attached to the terminal that
launched `run-vm`.

The Device Emulator is the visible host-side fake XR device. QEMU publishes its
headless virtual display through loopback RFB; both the emulator and XR bridge
consume it through the shared transport. See `tools/DeviceEmulator/README.md`.

The Sandbox VM is a small diagnostics environment. It contains AruiServer,
AruiBoot, AruiLogin, AruiDesktop, GStreamer, and debugging tools, but no Device Emulator, compiler, source-control
client, Nix CLI, desktop environment, compositor, or Xwayland. It boots
Linux/systemd, initializes Mesa, and provides SSH plus the requested graphics
inspection commands. It does not run any graphics-report service automatically.
The Sandbox exposes a headless, virgl-accelerated `virtio-vga-gl` display
and publishes its framebuffer through a loopback-only VNC/RFB endpoint. QEMU
uses the host AMD iGPU render node, leaving the NVIDIA GPU untouched. The
host-side Device Emulator consumes that framebuffer and mirrors boot output
into both eye panels. Serial console and SSH remain available for debugging.

Log in over the VM console as `aros`/`aros`, or connect through the loopback-only
QEMU SSH forwarding:

```bash
ssh -p 2222 aros@127.0.0.1
```

Then run diagnostics manually:

```bash
vulkaninfo --summary
glxinfo -B
xrinfo
```

The password is for the local development VM only. Port 2222 is bound to host
loopback, the guest firewall permits only SSH, and root SSH login is disabled.
The `aros` user belongs to `wheel`; use the same `aros` password when `sudo`
prompts for administrative access.
The locked nixpkgs revision does not ship a binary literally named `xrinfo`, so
AR-OS provides it as a thin alias for Khronos' `openxr_runtime_list`.

## Current limitations

The Sandbox now provides a working in-guest Monado OpenXR session and streams
independent raw RGBA eye frames to the Device Emulator after the RFB boot-display
phase. The Device Emulator supplies Monado's remote HMD head pose and IPD through the sandbox's dedicated tracking transport. Hand and controller input remain out of scope.

## XR Display Bridge

To view the boot console on a Quest 2 through WiVRn, start WiVRn and connect the
headset, then build AROSXRDisplayBridge and run:

    ./scripts/run-xr-display.sh
    ./scripts/run-sandbox.sh

The bridge and Device Emulator are independent consumers of the shared
AROSVirtualDisplay RFB transport and may run concurrently. The Sandbox sees its virgl-accelerated `virtio-vga-gl` display. See tools/XRDisplayBridge/README.md for
setup, architecture, lifecycle, diagnostics, and the future OpenXR proxy
boundary.

## Sandbox display and debugging

The Sandbox enables a virgl-accelerated `virtio-vga-gl` device backed by the
host AMD render node at PCI `06:00.0`. QEMU renders through EGL-headless while
continuing to export the scanout over loopback RFB for the Device Emulator and
XR Display Bridge. The Sandbox launcher supplies the host Mesa GBM/DRI paths to
the Nix-built QEMU process; the guest uses its `virtio_gpu` Mesa driver rather
than forcing llvmpipe. It also automatically logs the
aros user, and enables the Nix CLI/daemon with nix-command and flakes.
aros user into tty1 and runs:

    tmux new-session -A -s aros

Build and run it with:

    ./scripts/build-vm.sh
    ./scripts/run-sandbox.sh

The equivalent CMake targets are `build-sandbox` and `run-vm`. SSH and the
loopback-only gdbservers are Sandbox features and are absent from Base.

## Early ARUI lifecycle

Every VM build bundles four native systems. The ARUI repository owns
`AruiServer`; AR-OS owns `AruiBoot`, `AruiLogin`, and `AruiDesktop`. Nix patches
their ELF interpreters and runtime paths before placing them in the immutable OS
closure.

Monado is installed as the system's default OpenXR runtime. `AruiServer` opens
one long-lived OpenXR session and owns the runtime, scene, renderer, and
loopback-only presentation RPC endpoint. Boot, Login, and Desktop use
`IPresentationController` client proxies; they never link ARUI runtime, render,
or XR internals.

The units are ordered without handing off the XR session:

    monado-runtime.socket
             |
        arui-server.service    long-running runtime/renderer/RPC service
             |
        arui-boot.service      transient boot presentation client
             |
        arui-login.service     transient login presentation client
             |
        arui-desktop.service   long-running desktop policy client

Each system experience resets and replaces the current test presentation through
RPC. Switching stages does not restart `AruiServer`, the renderer, or the OpenXR
session.

Inspect the lifecycle with:

    systemctl status monado-runtime.socket arui-server arui-boot arui-login arui-desktop
    journalctl -b -u monado-runtime.service -u arui-server -u arui-boot -u arui-login -u arui-desktop


## Remote debugging ARUI systems

Sandbox VM images start persistent extended-remote gdbservers without delaying any
ARUI process. QEMU forwards them only onto host loopback:

| System | Host endpoint | Guest executable |
| --- | --- | --- |
| ARUI boot | `127.0.0.1:2345` | `AruiBoot` |
| ARUI login | `127.0.0.1:2346` | `AruiLogin` |
| ARUI desktop | `127.0.0.1:2347` | `AruiDesktop` |

The checked-in VS Code launch configurations connect with the matching
unstripped host executable. For the transient boot and login stages, the
extended-remote server starts a fresh guest process under GDB; no PID lookup is
needed. The desktop configuration attaches to the long-running service PID.

The equivalent manual boot sequence is:

    gdb build/src/Boot/AruiBoot
    (gdb) target extended-remote 127.0.0.1:2345
    (gdb) set remote exec-file /run/current-system/sw/bin/AruiBoot
    (gdb) run

To attach to the desktop instead:

    gdb build/src/Desktop/AruiDesktop
    (gdb) target extended-remote 127.0.0.1:2347
    (gdb) attach <pid>

Retrieve the desktop PID with:

    ssh -p 2222 aros@127.0.0.1       systemctl show --property MainPID --value arui-desktop.service

Boot and login are intentionally transient, so attempting to attach to their
systemd PIDs races their normal exit. Their launch configurations instead use
GDB's extended-remote `run` support. Neither service waits for the debugger
during ordinary startup. Base contains no gdbservers and exposes none of these
ports.

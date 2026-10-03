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

Nix constructs the minimal operating system and QEMU VM. CMake builds native
AR-OS software on the host. ARUI remains an independent Git submodule rather
than being added to the root CMake project.

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

AR-OS never packages or starts the ARUI Simulator, `AruiServer` (which currently
depends on the simulator), or `SimulatorViewProvider`.

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

The root project owns `src/` and `tools/`; it never calls
`add_subdirectory(AR-UI)`. Configure and build the development targets with:

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

## Build and run the VM

```bash
nix build .#vm
QEMU_OPTS=-enable-kvm ./result/bin/run-ar-os-vm
```

The root CMake project exposes convenience targets for the normal development
workflow. `run-vm` depends on `build-vm`, checks `/dev/kvm`, and explicitly
enables KVM acceleration:

```bash
cmake --build build --target build-vm
cmake --build build --target run-vm
```

The equivalent scripts are:

```bash
./scripts/build-vm.sh
./scripts/run-device-emulator.sh
./scripts/run-vm.sh
```

All writable VM state is kept under `.vm/`:

```text
.vm/
├── ar-os.qcow2   # persistent VM root filesystem
├── serial.log     # secondary serial-console diagnostics
├── shared/       # persistent host/guest exchange directory
└── run.*/        # per-run sockets and temporary files; removed on exit
```

The immutable kernel, initrd, and NixOS closure remain in `/nix/store`; they are
build outputs rather than VM runtime state.

The graphical `tty0` console is the primary boot console and is carried to the
Device Emulator through QEMU's loopback RFB display. The secondary `ttyS0`
console is retained in `.vm/serial.log`; it is not attached to the terminal that
launched `run-vm`.

The Device Emulator is the visible host-side fake XR device. QEMU publishes its
headless virtual display through loopback RFB; both the emulator and XR bridge
consume it through the shared transport. See `tools/DeviceEmulator/README.md`.

The VM is intentionally a small diagnostics image, not a development
environment. It contains no ARUI, Device Emulator, compiler, source-control
client, Nix CLI, desktop environment, compositor, or Xwayland. It boots
Linux/systemd, initializes Mesa, and provides SSH plus the requested graphics
inspection commands. It does not run any graphics-report service automatically.
QEMU exposes a headless `virtio-vga` display device and publishes its framebuffer
through a loopback-only VNC/RFB endpoint. The host-side Device Emulator consumes
that framebuffer and mirrors boot output into both eye panels. Serial console
and SSH remain available for debugging. The default runner deliberately does
not use VirGL because Nix QEMU's Mesa EGL/GBM stack cannot initialize this
host's proprietary NVIDIA render node.

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

The VM does not yet provide an XR device protocol, ARUI shell process, automatic
graphical session, or in-guest OpenXR integration. These are
explicit future integration points. They will be added only when the device OS
needs them; the current VM exists solely to prove boot and report graphics
capabilities.

## XR Display Bridge

To view the boot console on a Quest 2 through WiVRn, start WiVRn and connect the
headset, then build AROSXRDisplayBridge and run:

    ./scripts/run-xr-display.sh
    ./scripts/run-vm.sh

The bridge and Device Emulator are independent consumers of the shared
AROSVirtualDisplay RFB transport and may run concurrently. The VM still sees
only its normal virtio-vga display. See tools/XRDisplayBridge/README.md for
setup, architecture, lifecycle, diagnostics, and the future OpenXR proxy
boundary.

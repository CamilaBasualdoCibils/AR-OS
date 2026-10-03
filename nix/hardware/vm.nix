{ arosDebug, lib, ... }:
{
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_net" ];
  boot.kernelModules = [ "virtio_gpu" ];

  virtualisation.vmVariant.virtualisation = {
    # Keep NixOS graphics enabled in both profiles so its VM module does not
    # append -nographic. Debug mode supplies its own EGL-headless GL display,
    # renders virtio-vga-gl through the AMD iGPU, and exports scanout over RFB.
    graphics = true;
    memorySize = 1024;
    cores = 1;
    qemu.options = lib.optionals arosDebug [
      "-device virtio-vga-gl,blob=on,hostmem=512M"
      "-display egl-headless,rendernode=/dev/dri/by-path/pci-0000:06:00.0-render"
      "-vnc 127.0.0.1:1,share=force-shared"
      "-serial file:$AROS_VM_SERIAL_LOG"
      "-monitor none"
    ];
    qemu.consoles = lib.optionals arosDebug [ "ttyS0,115200n8" "tty0" ];
    forwardPorts = [{
      from = "host";
      host.address = "127.0.0.1";
      host.port = 2222;
      guest.port = 22;
    }] ++ lib.optionals arosDebug (map (port: {
      from = "host";
      host.address = "127.0.0.1";
      host.port = port;
      guest.port = port;
    }) [ 2345 2346 2347 ]);
  };
}

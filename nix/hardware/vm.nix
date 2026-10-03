{ arosDebug, lib, ... }:
{
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_net" ];
  boot.kernelModules = [ "virtio_gpu" ];

  virtualisation.vmVariant.virtualisation = {
    # Normal mode uses QEMU's regular graphical window. Debug mode keeps QEMU
    # headless and exports virtio-vga over loopback RFB to the host display tools.
    graphics = !arosDebug;
    memorySize = 1024;
    cores = 1;
    qemu.options = lib.optionals arosDebug [
      "-device virtio-vga"
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
    }];
  };
}

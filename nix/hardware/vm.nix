{ ... }:

{
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_net" ];
  boot.kernelModules = [ "virtio_gpu" ];

  virtualisation.vmVariant.virtualisation = {
    graphics = false;
    memorySize = 1024;
    cores = 1;
    qemu.options = [
      "-device virtio-vga"
      "-vnc 127.0.0.1:1,share=force-shared"
      "-serial file:$AROS_VM_SERIAL_LOG"
      "-monitor none"
    ];
    # tty0 is last and therefore becomes /dev/console. Boot and systemd output
    # goes to the framebuffer consumed by the Device Emulator, while ttyS0 is
    # retained as a secondary diagnostic console.
    qemu.consoles = [ "ttyS0,115200n8" "tty0" ];
    forwardPorts = [
      {
        from = "host";
        host.address = "127.0.0.1";
        host.port = 2222;
        guest.port = 22;
      }
    ];
  };
}

{ ... }:
{
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_net" ];
  boot.kernelModules = [ "virtio_gpu" ];
  virtualisation.vmVariant.virtualisation = {
    graphics = true;
    memorySize = 1024;
    cores = 1;
    qemu.options = [
      "-device virtio-vga-gl,blob=on,hostmem=512M"
      "-display egl-headless,rendernode=/dev/dri/by-path/pci-0000:06:00.0-render"
      "-vnc 127.0.0.1:1,share=force-shared"
      "-serial file:$VISROS_VM_SERIAL_LOG"
      "-monitor none"
    ];
    qemu.consoles = [ "ttyS0,115200n8" "tty0" ];
    forwardPorts = [{
      from = "host";
      host.address = "127.0.0.1";
      host.port = 2222;
      guest.port = 22;
    }] ++ map (port: {
      from = "host";
      host.address = "127.0.0.1";
      host.port = port;
      guest.port = port;
    }) [ 2345 2346 2347 4242 4243 4244 4245 ];
  };
}

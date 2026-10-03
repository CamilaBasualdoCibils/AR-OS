{ aruiBoot, aruiDesktop, aruiLogin, lib, pkgs, ... }:
let
  graphicsEnvironment = {
    LIBGL_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
    __EGL_VENDOR_LIBRARY_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d";
    XR_RUNTIME_JSON = "${pkgs.monado}/share/openxr/1/openxr_monado.json";
    XDG_RUNTIME_DIR = "/run/arui-monado";
    EGL_PLATFORM = "surfaceless";
    # Monado uses Vulkan while ARUI currently uses OpenGL. Force both APIs
    # onto Mesa's software device until the Sandbox exposes one virtual GPU
    # with compatible Vulkan/OpenGL external-memory support.
    LIBGL_ALWAYS_SOFTWARE = "1";
    XRT_COMPOSITOR_NULL = "1";
    ARUI_FONT_PATH = "${pkgs.noto-fonts}/share/fonts/noto/NotoSans.ttf";
  };
  aruiServiceConfig = {
    Type = "oneshot";
    User = "aros";
    SupplementaryGroups = [ "video" "render" ];
    Restart = "no";
    StandardOutput = "journal+console";
    StandardError = "journal+console";
  };
in {
  imports = [ ../modules/graphics.nix ];
  # Generic buildable defaults; concrete hardware configurations override
  # these with their persistent root filesystem and boot loader.
  fileSystems."/" = {
    fsType = lib.mkDefault "tmpfs";
  };
  boot.loader.grub.devices = lib.mkDefault [ "nodev" ];
  networking.hostName = "ar-os";
  networking.useDHCP = true;
  users.users.aros = {
    isNormalUser = true;
    extraGroups = [ "video" "render" ];
  };
  services.monado = { enable = true; defaultRuntime = true; };

  systemd.tmpfiles.rules = [ "d /run/arui-monado 0750 aros users -" ];
  systemd.sockets.monado-runtime = {
    description = "Monado OpenXR runtime socket for ARUI";
    wantedBy = [ "sockets.target" ];
    socketConfig = {
      ListenStream = "/run/arui-monado/monado_comp_ipc";
      SocketUser = "aros";
      SocketGroup = "users";
      RemoveOnStop = true;
      FlushPending = true;
    };
  };
  systemd.services.monado-runtime = {
    description = "Monado OpenXR runtime for ARUI";
    requires = [ "monado-runtime.socket" ];
    after = [ "monado-runtime.socket" "systemd-udev-trigger.service" ];
    environment = graphicsEnvironment;
    serviceConfig = {
      Type = "simple";
      User = "aros";
      SupplementaryGroups = [ "video" "render" ];
      ExecStart = "${pkgs.monado}/bin/monado-service";
      Restart = "on-failure";
    };
  };

  environment.systemPackages = [ aruiBoot aruiLogin aruiDesktop ];
  systemd.services.arui-boot = {
    description = "ARUI boot system";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    before = [ "arui-login.service" ];
    after = [ "monado-runtime.socket" "systemd-udev-trigger.service" ];
    wants = [ "monado-runtime.socket" "systemd-udev-trigger.service" ];
    environment = graphicsEnvironment;
    serviceConfig = aruiServiceConfig // { ExecStart = "${aruiBoot}/bin/AruiBoot"; };
  };
  systemd.services.arui-login = {
    description = "ARUI login system";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    after = [ "arui-boot.service" ];
    before = [ "arui-desktop.service" ];
    wants = [ "arui-boot.service" ];
    environment = graphicsEnvironment;
    serviceConfig = aruiServiceConfig // { ExecStart = "${aruiLogin}/bin/AruiLogin"; };
  };
  systemd.services.arui-desktop = {
    description = "ARUI desktop system";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    after = [ "arui-login.service" ];
    wants = [ "arui-login.service" ];
    environment = graphicsEnvironment;
    serviceConfig = aruiServiceConfig // {
      Type = "simple";
      ExecStart = "${aruiDesktop}/bin/AruiDesktop";
    };
  };
  documentation.enable = false;
  nix.enable = lib.mkDefault false;
  system.stateVersion = "25.05";
}

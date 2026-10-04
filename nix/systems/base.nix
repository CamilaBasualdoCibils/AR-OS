{ visrBoot, visrDesktop, visrLogin, visrServer, lib, pkgs, ... }:
let
  visrServerReadyFile = "/run/visr-server/xr-first-frame";
  waitForVisrServerReady = pkgs.writeShellScript "wait-for-visr-server-ready" ''
    while [ ! -e ${visrServerReadyFile} ]; do
      sleep 0.1
    done
  '';

  graphicsEnvironment = {
    LIBGL_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
    __EGL_VENDOR_LIBRARY_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d";
    XR_RUNTIME_JSON = "${pkgs.monado}/share/openxr/1/openxr_monado.json";
    XDG_RUNTIME_DIR = "/run/visr-monado";
    XDG_CONFIG_HOME = "/etc/xdg";
    EGL_PLATFORM = "surfaceless";

    # Monado uses Vulkan while VISR currently uses OpenGL. Force both APIs
    # onto Mesa's software device until the Sandbox exposes one virtual GPU
    # with compatible Vulkan/OpenGL external-memory support.
    LIBGL_ALWAYS_SOFTWARE = "1";
    XRT_COMPOSITOR_NULL = "1";

    VISR_FONT_PATH = "${pkgs.noto-fonts}/share/fonts/noto/NotoSans.ttf";
  };

  experienceServiceConfig = {
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

  networking.hostName = "visr-os";
  # Keep VISR's early, local RPC endpoint resolvable before network services.
  networking.hosts."127.0.0.1" = [ "localhost" ];
  networking.useDHCP = true;

  users.users.aros = {
    isNormalUser = true;
    extraGroups = [ "video" "render" ];
  };

  services.monado = {
    enable = true;
    defaultRuntime = true;
  };

  environment.etc."xdg/monado/config_v0.json".text = builtins.toJSON {
    active = "remote";
    remote = { version = 0; port = 4244; };
  };

  systemd.tmpfiles.rules = [
    "d /run/visr-monado 0750 aros users -"
    "d /run/visr-server 0750 aros users -"
  ];

  #
  # Early VISR startup target.
  #
  # The normal boot process is not allowed to reach multi-user.target until
  # the initial VISR boot experience has completed.
  #
  systemd.targets.visr-early = {
    description = "Early VISR startup";
    wantedBy = [ "sysinit.target" ];

    # Start VISR as soon as the basic system initialization is available.
    after = [
      "local-fs.target"
      "systemd-tmpfiles-setup.service"
      "systemd-udev-trigger.service"
    ];

    before = [ "multi-user.target" ];

    requires = [
      "visr-server.service"
      "visr-boot.service"
    ];
  };

  #
  # OpenXR / Monado
  #

  systemd.sockets.monado-runtime = {
    description = "Monado OpenXR runtime socket for VISR";
    wantedBy = [ "sockets.target" ];

    socketConfig = {
      ListenStream = "/run/visr-monado/monado_comp_ipc";
      SocketUser = "aros";
      SocketGroup = "users";
      RemoveOnStop = true;
      FlushPending = true;
    };
  };

  systemd.services.monado-runtime = {
    description = "Monado OpenXR runtime for VISR";

    requires = [ "monado-runtime.socket" ];

    after = [
      "monado-runtime.socket"
      "systemd-udev-trigger.service"
    ];

    environment = graphicsEnvironment;

    serviceConfig = {
      Type = "simple";
      User = "aros";
      SupplementaryGroups = [ "video" "render" ];
      ExecStart = "${pkgs.monado}/bin/monado-service";
      Restart = "on-failure";
    };
  };

  environment.systemPackages = [
    visrServer
    visrBoot
    visrLogin
    visrDesktop
  ];

  #
  # 1. VISR SERVER
  #
  # Start this first, as early as possible.
  #

  systemd.services.visr-server = {
    description = "VISR runtime and presentation service";

    unitConfig.DefaultDependencies = false;

    wantedBy = [ "visr-early.target" ];

    before = [
      "visr-boot.service"
      "visr-early.target"
      "multi-user.target"
    ];

    after = [
      "local-fs.target"
      "systemd-tmpfiles-setup.service"
      "systemd-udev-trigger.service"
      "monado-runtime.socket"
    ];

    wants = [
      "monado-runtime.socket"
    ];

    environment = graphicsEnvironment // {
      VISR_SERVER_READY_FILE = visrServerReadyFile;
    };

    serviceConfig = {
      Type = "simple";
      User = "aros";
      SupplementaryGroups = [ "video" "render" ];

      ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${visrServerReadyFile}";
      ExecStart = "${visrServer}/bin/VisrServer";
      ExecStartPost = waitForVisrServerReady;
      TimeoutStartSec = "infinity";

      Restart = "on-failure";

      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };

  #
  # 2. VISR BOOT
  #
  # Cannot start until visr-server has started.
  # Because this is Type=oneshot, visr-early.target will not be considered
  # reached until VisrBoot exits successfully.
  #

  systemd.services.visr-boot = {
    description = "VISR boot system";

    unitConfig.DefaultDependencies = false;

    wantedBy = [ "visr-early.target" ];

    requires = [ "visr-server.service" ];

    after = [ "visr-server.service" ];

    before = [
      "visr-early.target"
      "multi-user.target"
      "visr-login.service"
    ];

    environment = graphicsEnvironment;

    serviceConfig =
      experienceServiceConfig
      // {
        ExecStart = "${visrBoot}/bin/VisrBoot";
      };
  };

  #
  # 3. LOGIN
  #

  systemd.services.visr-login = {
    description = "VISR login system";

    unitConfig.DefaultDependencies = false;

    wantedBy = [ "multi-user.target" ];

    requires = [
      "visr-server.service"
      "visr-boot.service"
    ];

    after = [
      "visr-early.target"
      "visr-server.service"
      "visr-boot.service"
    ];

    before = [ "visr-desktop.service" ];

    environment = graphicsEnvironment;

    serviceConfig =
      experienceServiceConfig
      // {
        ExecStart = "${visrLogin}/bin/VisrLogin";
      };
  };

  #
  # 4. DESKTOP
  #

  systemd.services.visr-desktop = {
    description = "VISR desktop system";

    unitConfig.DefaultDependencies = false;

    wantedBy = [ "multi-user.target" ];

    requires = [
      "visr-server.service"
      "visr-login.service"
    ];

    after = [
      "visr-early.target"
      "visr-server.service"
      "visr-login.service"
    ];

    environment = graphicsEnvironment;

    serviceConfig =
      experienceServiceConfig
      // {
        Type = "simple";
        ExecStart = "${visrDesktop}/bin/VisrDesktop";
      };
  };

  documentation.enable = false;
  nix.enable = lib.mkDefault false;

  system.stateVersion = "25.05";
}
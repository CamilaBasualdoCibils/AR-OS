{ aruiBoot, aruiDesktop, aruiLogin, aruiServer, lib, pkgs, ... }:
let
  aruiServerReadyFile = "/run/arui-server/xr-first-frame";
  waitForAruiServerReady = pkgs.writeShellScript "wait-for-arui-server-ready" ''
    while [ ! -e ${aruiServerReadyFile} ]; do
      sleep 0.1
    done
  '';

  graphicsEnvironment = {
    LIBGL_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
    __EGL_VENDOR_LIBRARY_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d";
    XR_RUNTIME_JSON = "${pkgs.monado}/share/openxr/1/openxr_monado.json";
    XDG_RUNTIME_DIR = "/run/arui-monado";
    XDG_CONFIG_HOME = "/etc/xdg";
    EGL_PLATFORM = "surfaceless";

    # Monado uses Vulkan while ARUI currently uses OpenGL. Force both APIs
    # onto Mesa's software device until the Sandbox exposes one virtual GPU
    # with compatible Vulkan/OpenGL external-memory support.
    LIBGL_ALWAYS_SOFTWARE = "1";
    XRT_COMPOSITOR_NULL = "1";

    ARUI_FONT_PATH = "${pkgs.noto-fonts}/share/fonts/noto/NotoSans.ttf";
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

  networking.hostName = "ar-os";
  # Keep ARUI's early, local RPC endpoint resolvable before network services.
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
    "d /run/arui-monado 0750 aros users -"
    "d /run/arui-server 0750 aros users -"
  ];

  #
  # Early ARUI startup target.
  #
  # The normal boot process is not allowed to reach multi-user.target until
  # the initial ARUI boot experience has completed.
  #
  systemd.targets.arui-early = {
    description = "Early ARUI startup";
    wantedBy = [ "sysinit.target" ];

    # Start ARUI as soon as the basic system initialization is available.
    after = [
      "local-fs.target"
      "systemd-tmpfiles-setup.service"
      "systemd-udev-trigger.service"
    ];

    before = [ "multi-user.target" ];

    requires = [
      "arui-server.service"
      "arui-boot.service"
    ];
  };

  #
  # OpenXR / Monado
  #

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
    aruiServer
    aruiBoot
    aruiLogin
    aruiDesktop
  ];

  #
  # 1. ARUI SERVER
  #
  # Start this first, as early as possible.
  #

  systemd.services.arui-server = {
    description = "ARUI runtime and presentation service";

    unitConfig.DefaultDependencies = false;

    wantedBy = [ "arui-early.target" ];

    before = [
      "arui-boot.service"
      "arui-early.target"
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
      ARUI_SERVER_READY_FILE = aruiServerReadyFile;
    };

    serviceConfig = {
      Type = "simple";
      User = "aros";
      SupplementaryGroups = [ "video" "render" ];

      ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${aruiServerReadyFile}";
      ExecStart = "${aruiServer}/bin/AruiServer";
      ExecStartPost = waitForAruiServerReady;
      TimeoutStartSec = "infinity";

      Restart = "on-failure";

      StandardOutput = "journal+console";
      StandardError = "journal+console";
    };
  };

  #
  # 2. ARUI BOOT
  #
  # Cannot start until arui-server has started.
  # Because this is Type=oneshot, arui-early.target will not be considered
  # reached until AruiBoot exits successfully.
  #

  systemd.services.arui-boot = {
    description = "ARUI boot system";

    unitConfig.DefaultDependencies = false;

    wantedBy = [ "arui-early.target" ];

    requires = [ "arui-server.service" ];

    after = [ "arui-server.service" ];

    before = [
      "arui-early.target"
      "multi-user.target"
      "arui-login.service"
    ];

    environment = graphicsEnvironment;

    serviceConfig =
      experienceServiceConfig
      // {
        ExecStart = "${aruiBoot}/bin/AruiBoot";
      };
  };

  #
  # 3. LOGIN
  #

  systemd.services.arui-login = {
    description = "ARUI login system";

    unitConfig.DefaultDependencies = false;

    wantedBy = [ "multi-user.target" ];

    requires = [
      "arui-server.service"
      "arui-boot.service"
    ];

    after = [
      "arui-early.target"
      "arui-server.service"
      "arui-boot.service"
    ];

    before = [ "arui-desktop.service" ];

    environment = graphicsEnvironment;

    serviceConfig =
      experienceServiceConfig
      // {
        ExecStart = "${aruiLogin}/bin/AruiLogin";
      };
  };

  #
  # 4. DESKTOP
  #

  systemd.services.arui-desktop = {
    description = "ARUI desktop system";

    unitConfig.DefaultDependencies = false;

    wantedBy = [ "multi-user.target" ];

    requires = [
      "arui-server.service"
      "arui-login.service"
    ];

    after = [
      "arui-early.target"
      "arui-server.service"
      "arui-login.service"
    ];

    environment = graphicsEnvironment;

    serviceConfig =
      experienceServiceConfig
      // {
        Type = "simple";
        ExecStart = "${aruiDesktop}/bin/AruiDesktop";
      };
  };

  documentation.enable = false;
  nix.enable = lib.mkDefault false;

  system.stateVersion = "25.05";
}
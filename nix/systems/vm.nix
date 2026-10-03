{ arosDebug, aruiBoot, aruiDesktop, aruiLogin, lib, pkgs, ... }:
let
  graphicsEnvironment = {
    LIBGL_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
    __EGL_VENDOR_LIBRARY_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d";
    XR_RUNTIME_JSON = "${pkgs.monado}/share/openxr/1/openxr_monado.json";
    XDG_RUNTIME_DIR = "/run/arui-monado";
    EGL_PLATFORM = "surfaceless";
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
  imports = [ ../hardware/vm.nix ../modules/graphics.nix ];

  networking.hostName = "ar-os";
  networking.useDHCP = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ] ++ lib.optionals arosDebug [ 2345 2346 2347 ];
  };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };
  users.users.aros = {
    isNormalUser = true;
    initialPassword = "aros";
    extraGroups = [ "wheel" "video" "render" ];
  };
  security.sudo.wheelNeedsPassword = true;

  services.monado = {
    enable = true;
    defaultRuntime = true;
  };

  # The ARUI systems run before a graphical login/user manager exists, so host
  # Monado's socket and service at system scope under the eventual desktop user.
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

  environment.systemPackages = [ aruiBoot aruiLogin aruiDesktop ]
    ++ lib.optionals arosDebug [ pkgs.tmux pkgs.gdb ];

  # Acquire graphics as early as possible. This transient process owns the
  # presenter only while boot visualization is active, then dismantles it.
  # Extended-remote servers do not own or pause the inferior. QEMU exposes
  # them only on host loopback; inside the debug guest they bind its private
  # SLIRP address rather than every interface.
  systemd.services.arui-boot-gdbserver = lib.mkIf arosDebug {
    description = "GDB server for ARUI boot";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    after = [ "sshd.service" ];
    before = [ "arui-boot.service" ];
    environment = graphicsEnvironment;
    serviceConfig = {
      User = "aros";
      SupplementaryGroups = [ "video" "render" ];
      ExecStart = "${pkgs.gdb}/bin/gdbserver --multi 10.0.2.15:2345";
      Restart = "always";
    };
  };
  systemd.services.arui-login-gdbserver = lib.mkIf arosDebug {
    description = "GDB server for ARUI login";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    after = [ "sshd.service" ];
    before = [ "arui-login.service" ];
    environment = graphicsEnvironment;
    serviceConfig = {
      User = "aros";
      SupplementaryGroups = [ "video" "render" ];
      ExecStart = "${pkgs.gdb}/bin/gdbserver --multi 10.0.2.15:2346";
      Restart = "always";
    };
  };
  systemd.services.arui-desktop-gdbserver = lib.mkIf arosDebug {
    description = "GDB server for ARUI desktop";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    after = [ "sshd.service" ];
    before = [ "arui-desktop.service" ];
    environment = graphicsEnvironment;
    serviceConfig = {
      User = "aros";
      SupplementaryGroups = [ "video" "render" ];
      ExecStart = "${pkgs.gdb}/bin/gdbserver --multi 10.0.2.15:2347";
      Restart = "always";
    };
  };

  systemd.services.arui-boot = {
    description = "ARUI boot system";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    before = [ "arui-login.service" ];
    after = [ "sshd.service" "monado-runtime.socket" "systemd-udev-trigger.service" ];
    wants = [ "monado-runtime.socket" "systemd-udev-trigger.service" ];
    requires = [ "sshd.service" ];
    environment = graphicsEnvironment // lib.optionalAttrs arosDebug { ARUI_GDB_ATTACH = "1"; };
    serviceConfig = aruiServiceConfig // {
      ExecStart = "${aruiBoot}/bin/AruiBoot";
    };
  };

  systemd.services.arui-login = {
    description = "ARUI login system";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    after = [ "arui-boot.service" ];
    before = [ "arui-desktop.service" ];
    wants = [ "arui-boot.service" ];
    environment = graphicsEnvironment // lib.optionalAttrs arosDebug { ARUI_GDB_ATTACH = "1"; };
    serviceConfig = aruiServiceConfig // {
      ExecStart = "${aruiLogin}/bin/AruiLogin";
    };
  };

  systemd.services.arui-desktop = {
    description = "ARUI desktop system";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    after = [ "arui-login.service" ];
    wants = [ "arui-login.service" ];
    environment = graphicsEnvironment // lib.optionalAttrs arosDebug { ARUI_GDB_ATTACH = "1"; };
    serviceConfig = aruiServiceConfig // {
      Type = "simple";
      ExecStart = "${aruiDesktop}/bin/AruiDesktop";
    };
  };

  services.getty.autologinUser = lib.mkIf arosDebug "aros";
  programs.bash.loginShellInit = lib.mkIf arosDebug ''
    if [[ "$(tty)" == /dev/tty1 && -z "''${TMUX-}" ]]; then
      exec ${pkgs.tmux}/bin/tmux new-session -A -s aros
    fi
  '';

  documentation.enable = false;
  nix.enable = arosDebug;
  nix.settings.experimental-features = lib.optionals arosDebug [ "nix-command" "flakes" ];
  system.stateVersion = "25.05";
}

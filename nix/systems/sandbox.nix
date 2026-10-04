{ pkgs, ... }:
let
  gdbServer = name: port: {
    description = "GDB server for ARUI ${name}";
    unitConfig.DefaultDependencies = false;
    wantedBy = [ "multi-user.target" ];
    after = [ "sshd.service" ];
    serviceConfig = {
      User = "aros";
      SupplementaryGroups = [ "video" "render" ];
      ExecStart = "${pkgs.gdb}/bin/gdbserver --multi 10.0.2.15:${toString port}";
      Restart = "always";
    };
  };
in {
  imports = [ ./base.nix ../hardware/qemu.nix ../modules/sandbox-streaming.nix ];
  networking.firewall.allowedTCPPorts = [ 22 2345 2346 2347 4242 4243 4244 4245 ];
  systemd.services.arui-server.environment.ARUI_PRESENTATION_BIND_HOST = "0.0.0.0";
  services.openssh = {
    enable = true;
    settings = { PasswordAuthentication = true; PermitRootLogin = "no"; };
  };
  users.users.aros = {
    initialPassword = "aros";
    extraGroups = [ "wheel" ];
  };
  security.sudo.wheelNeedsPassword = true;
  environment.systemPackages = [ pkgs.tmux pkgs.gdb ];
  systemd.services.arui-boot-gdbserver = gdbServer "boot" 2345;
  systemd.services.arui-login-gdbserver = gdbServer "login" 2346;
  systemd.services.arui-desktop-gdbserver = gdbServer "desktop" 2347;
  # Boot is part of sysinit and must not wait for SSH: SSH itself is ordered
  # after sysinit, so that dependency creates a cycle and starts boot before
  # its ARUI prerequisites are reliable.  GDB attach permission needs no SSH.
  systemd.services.arui-boot.environment.ARUI_GDB_ATTACH = "1";
  systemd.services.arui-login.environment.ARUI_GDB_ATTACH = "1";
  systemd.services.arui-desktop.environment.ARUI_GDB_ATTACH = "1";
  services.getty.autologinUser = "aros";
  programs.bash.loginShellInit = ''
    if [[ "$(tty)" == /dev/tty1 && -z "''${TMUX-}" ]]; then
      exec ${pkgs.tmux}/bin/tmux new-session -A -s aros
    fi
  '';
  nix.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}

{ arosDebug, lib, pkgs, ... }:
{
  imports = [ ../hardware/vm.nix ../modules/graphics.nix ];

  networking.hostName = "ar-os";
  networking.useDHCP = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
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
    extraGroups = [ "wheel" ];
  };
  security.sudo.wheelNeedsPassword = true;

  # Debug boots go directly from tty1 autologin into one persistent development
  # shell. SSH and normal-mode logins retain ordinary login-shell behavior.
  services.getty.autologinUser = lib.mkIf arosDebug "aros";
  programs.bash.loginShellInit = lib.mkIf arosDebug ''
    if [[ "$(tty)" == /dev/tty1 && -z "''${TMUX-}" ]]; then
      exec ${pkgs.tmux}/bin/tmux new-session -A -s aros
    fi
  '';
  environment.systemPackages = lib.optionals arosDebug [ pkgs.tmux ];

  documentation.enable = false;
  nix.enable = arosDebug;
  nix.settings.experimental-features = lib.optionals arosDebug [ "nix-command" "flakes" ];
  system.stateVersion = "25.05";
}

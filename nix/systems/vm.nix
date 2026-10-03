{ ... }:

{
  imports = [
    ../hardware/vm.nix
    ../modules/graphics.nix
  ];

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

  documentation.enable = false;
  nix.enable = false;

  system.stateVersion = "25.05";
}

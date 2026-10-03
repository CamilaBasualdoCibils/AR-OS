{ pkgs, ... }:

let
  xrinfo = pkgs.writeShellScriptBin "xrinfo" ''
    exec ${pkgs.openxr-loader}/bin/openxr_runtime_list "$@"
  '';
in
{
  hardware.graphics.enable = true;

  environment.systemPackages = [
    pkgs.mesa-demos
    pkgs.openxr-loader
    pkgs.vulkan-tools
    xrinfo
  ];
}

{
  description = "AR-OS standalone NixOS image and native software";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      vmSystem = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./nix/systems/vm.nix ];
      };
    in
    {
      packages.${system}.vm = vmSystem.config.system.build.vm;
    };
}

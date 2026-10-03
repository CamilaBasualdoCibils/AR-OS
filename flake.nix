{
  description = "AR-OS standalone NixOS image and native software";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      makeVm = arosDebug: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit arosDebug; };
        modules = [ ./nix/systems/vm.nix ];
      };
      normalVm = makeVm false;
      debugVm = makeVm true;
    in {
      packages.${system} = {
        vm = normalVm.config.system.build.vm;
        vm-debug = debugVm.config.system.build.vm;
      };
    };
}

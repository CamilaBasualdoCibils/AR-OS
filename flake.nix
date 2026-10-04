{
  description = "VISR OS standalone NixOS image and native software";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      runtimeInputs = [
        pkgs.libglvnd pkgs.libuuid pkgs.vulkan-loader pkgs.stdenv.cc.cc.lib
        pkgs.libice pkgs.libsm pkgs.libx11 pkgs.libxau pkgs.libxdmcp
        pkgs.libxext pkgs.libxcb
      ];
      bundledExecutable = { envName, executable, pname }:
        let hostPath = builtins.getEnv envName;
        in if hostPath == "" then
          pkgs.writeShellScriptBin executable ''
            echo "${executable} was not bundled; build VISR OS through scripts/build-vm.sh" >&2
            exit 127
          ''
        else pkgs.stdenv.mkDerivation {
          inherit pname;
          version = "0.1.0";
          src = builtins.path {
            path = /. + hostPath;
            name = "${executable}-unpatched";
          };
          dontUnpack = true;
          nativeBuildInputs = [ pkgs.autoPatchelfHook ];
          buildInputs = runtimeInputs;
          installPhase = ''
            install -Dm755 "$src" "$out/bin/${executable}"
          '';
        };
      visrServer = bundledExecutable {
        envName = "VISROS_VISR_SERVER"; executable = "VisrServer"; pname = "visr-server";
      };
      visrBoot = bundledExecutable {
        envName = "VISROS_VISR_BOOT"; executable = "VisrBoot"; pname = "visr-boot";
      };
      visrLogin = bundledExecutable {
        envName = "VISROS_VISR_LOGIN"; executable = "VisrLogin"; pname = "visr-login";
      };
      visrDesktop = bundledExecutable {
        envName = "VISROS_VISR_DESKTOP"; executable = "VisrDesktop"; pname = "visr-desktop";
      };
      makeSystem = module: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit visrServer visrBoot visrLogin visrDesktop; };
        modules = [ module ];
      };
      baseSystem = makeSystem ./nix/systems/base.nix;
      sandboxSystem = makeSystem ./nix/systems/sandbox.nix;
    in {
      packages.${system} = {
        base = baseSystem.config.system.build.toplevel;
        sandbox = sandboxSystem.config.system.build.vm;
      };
      nixosConfigurations = { base = baseSystem; sandbox = sandboxSystem; };
    };
}

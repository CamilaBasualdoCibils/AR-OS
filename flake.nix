{
  description = "AR-OS standalone NixOS image and native software";
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
            echo "${executable} was not bundled; build AR-OS through scripts/build-vm.sh" >&2
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
      aruiBoot = bundledExecutable {
        envName = "AROS_ARUI_BOOT"; executable = "AruiBoot"; pname = "arui-boot";
      };
      aruiLogin = bundledExecutable {
        envName = "AROS_ARUI_LOGIN"; executable = "AruiLogin"; pname = "arui-login";
      };
      aruiDesktop = bundledExecutable {
        envName = "AROS_ARUI_DESKTOP"; executable = "AruiDesktop"; pname = "arui-desktop";
      };
      makeVm = arosDebug: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit arosDebug aruiBoot aruiLogin aruiDesktop; };
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

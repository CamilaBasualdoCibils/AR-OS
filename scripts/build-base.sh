#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ -z "${VISROS_VISR_SERVER-}" || -z "${VISROS_VISR_DESKTOP-}" || -z "${VISROS_VISR_LOGIN-}" || -z "${VISROS_VISR_BOOT-}" ]]; then
    if [[ ! -f build/CMakeCache.txt ]]; then
        cmake --preset vcpkg-preset -DBUILD_TESTING=OFF
    fi
    cmake --build build --target VisrServer VisrBoot VisrLogin VisrDesktop
    VISROS_VISR_SERVER="$(pwd -P)/build/VISR/Server/Runtime/VisrServer"
    VISROS_VISR_BOOT="$(pwd -P)/build/src/Boot/VisrBoot"
    VISROS_VISR_LOGIN="$(pwd -P)/build/src/Login/VisrLogin"
    VISROS_VISR_DESKTOP="$(pwd -P)/build/src/Desktop/VisrDesktop"
fi
for artifact in "$VISROS_VISR_SERVER" "$VISROS_VISR_BOOT" "$VISROS_VISR_LOGIN" "$VISROS_VISR_DESKTOP"; do
    if [[ ! -x "$artifact" ]]; then
        echo "VISR system executable was not built at $artifact" >&2
        exit 1
    fi
done
export VISROS_VISR_SERVER VISROS_VISR_BOOT VISROS_VISR_LOGIN VISROS_VISR_DESKTOP

echo "Building the hardware-independent VISR OS Base closure..."
flake_ref="path:$(pwd -P)"
exec nix --extra-experimental-features "nix-command flakes" \
    build --impure "$flake_ref#base" -o result-base "$@"

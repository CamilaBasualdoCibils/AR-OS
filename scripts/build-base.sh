#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ -z "${AROS_ARUI_SERVER-}" || -z "${AROS_ARUI_DESKTOP-}" || -z "${AROS_ARUI_LOGIN-}" || -z "${AROS_ARUI_BOOT-}" ]]; then
    if [[ ! -f build/CMakeCache.txt ]]; then
        cmake --preset vcpkg-preset -DBUILD_TESTING=OFF
    fi
    cmake --build build --target AruiServer AruiBoot AruiLogin AruiDesktop
    AROS_ARUI_SERVER="$(pwd -P)/build/AR-UI/Server/Runtime/AruiServer"
    AROS_ARUI_BOOT="$(pwd -P)/build/src/Boot/AruiBoot"
    AROS_ARUI_LOGIN="$(pwd -P)/build/src/Login/AruiLogin"
    AROS_ARUI_DESKTOP="$(pwd -P)/build/src/Desktop/AruiDesktop"
fi
for artifact in "$AROS_ARUI_SERVER" "$AROS_ARUI_BOOT" "$AROS_ARUI_LOGIN" "$AROS_ARUI_DESKTOP"; do
    if [[ ! -x "$artifact" ]]; then
        echo "ARUI system executable was not built at $artifact" >&2
        exit 1
    fi
done
export AROS_ARUI_SERVER AROS_ARUI_BOOT AROS_ARUI_LOGIN AROS_ARUI_DESKTOP

echo "Building the hardware-independent AR-OS Base closure..."
flake_ref="path:$(pwd -P)"
exec nix --extra-experimental-features "nix-command flakes" \
    build --impure "$flake_ref#base" -o result-base "$@"

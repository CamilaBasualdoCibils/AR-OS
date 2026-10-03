#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ -z "${AROS_ARUI_DESKTOP-}" || -z "${AROS_ARUI_LOGIN-}" || -z "${AROS_ARUI_BOOT-}" ]]; then
    if [[ ! -f build/CMakeCache.txt ]]; then
        cmake --preset vcpkg-preset -DBUILD_TESTING=OFF
    fi
    cmake --build build --target AruiBoot AruiLogin AruiDesktop
    AROS_ARUI_BOOT="$(pwd -P)/build/src/Boot/AruiBoot"
    AROS_ARUI_LOGIN="$(pwd -P)/build/AR-UI/Server/Login/AruiLogin"
    AROS_ARUI_DESKTOP="$(pwd -P)/build/AR-UI/Server/Desktop/AruiDesktop"
fi
for artifact in "$AROS_ARUI_BOOT" "$AROS_ARUI_LOGIN" "$AROS_ARUI_DESKTOP"; do
    if [[ ! -x "$artifact" ]]; then
        echo "ARUI system executable was not built at $artifact" >&2
        exit 1
    fi
done
export AROS_ARUI_BOOT AROS_ARUI_LOGIN AROS_ARUI_DESKTOP

mode="normal"
if [[ "${1-}" == "--debug" ]]; then mode="debug"; shift
elif [[ "${1-}" == "--normal" ]]; then shift
fi

if [[ "$mode" == "debug" ]]; then
    package="vm-debug"; output="result-debug"
else
    package="vm"; output="result"
fi

echo "Building AR-OS VM in $mode mode with boot, login, and desktop systems..."
exec nix --extra-experimental-features "nix-command flakes" \
    --option warn-dirty false build --impure ".#$package" -o "$output" "$@"

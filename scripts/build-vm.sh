#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

mode="normal"
if [[ "${1-}" == "--debug" ]]; then mode="debug"; shift
elif [[ "${1-}" == "--normal" ]]; then shift
fi

if [[ "$mode" == "debug" ]]; then
    package="vm-debug"; output="result-debug"
else
    package="vm"; output="result"
fi

echo "Building AR-OS VM in $mode mode..."
exec nix --extra-experimental-features "nix-command flakes" \
    --option warn-dirty false build ".#$package" -o "$output" "$@"

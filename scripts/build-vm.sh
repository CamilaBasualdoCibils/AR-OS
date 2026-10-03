#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

exec nix \
    --extra-experimental-features "nix-command flakes" \
    --option warn-dirty false \
    build \
    "path:.#vm" \
    -o result \
    "$@"
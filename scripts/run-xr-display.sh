#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for bridge in build/tools/XRDisplayBridge/ar-os-xr-display build/tools/XRDisplayBridge/Debug/ar-os-xr-display build/tools/XRDisplayBridge/Release/ar-os-xr-display; do
  if [[ -x "$bridge" ]]; then exec "$bridge" "$@"; fi
done
echo "XR Display Bridge not found; configure and build target AROSXRDisplayBridge first." >&2
exit 1

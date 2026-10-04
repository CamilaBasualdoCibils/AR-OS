#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
for bridge in build/tools/XRDisplayBridge/visr-os-xr-display build/tools/XRDisplayBridge/Debug/visr-os-xr-display build/tools/XRDisplayBridge/Release/visr-os-xr-display; do
  if [[ -x "$bridge" ]]; then exec "$bridge" "$@"; fi
done
echo "XR Display Bridge not found; configure and build target VISROSXRDisplayBridge first." >&2
exit 1

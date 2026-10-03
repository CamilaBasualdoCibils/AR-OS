#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

for emulator in \
    build/tools/DeviceEmulator/ar-os-device-emulator \
    build/tools/DeviceEmulator/Debug/ar-os-device-emulator \
    build/tools/DeviceEmulator/Release/ar-os-device-emulator; do
    if [[ -x "$emulator" ]]; then
        exec "$emulator" "$@"
    fi
done

echo "Device Emulator not found; configure and build target AROSDeviceEmulator first." >&2
exit 1

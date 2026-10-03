#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
repository_root="$(pwd -P)"

mode="normal"
if [[ "${1-}" == "--debug" ]]; then mode="debug"; shift
elif [[ "${1-}" == "--normal" ]]; then shift
fi

if [[ "$mode" == "debug" ]]; then
    result_path="result-debug"; disk_name="ar-os-debug.qcow2"
else
    result_path="result"; disk_name="ar-os.qcow2"
fi

runner="$result_path/bin/run-ar-os-vm"
if [[ ! -x "$runner" ]]; then
    echo "$mode VM runner not found; run ./scripts/build-vm.sh --$mode first." >&2
    exit 1
fi

vm_state_dir="$repository_root/.vm"
mkdir -p "$vm_state_dir/shared"
runtime_dir="$(mktemp -d "$vm_state_dir/run.XXXXXXXX")"
runner_pid=""
cleanup() {
    if [[ -n "$runner_pid" ]]; then
        kill -- "-$runner_pid" 2>/dev/null || true
        wait "$runner_pid" 2>/dev/null || true
        runner_pid=""
    fi
    rm -rf -- "$runtime_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

export NIX_DISK_IMAGE="$vm_state_dir/$disk_name"
export AROS_VM_SERIAL_LOG="$vm_state_dir/serial.log"
export SHARED_DIR="$vm_state_dir/shared"
export TMPDIR="$runtime_dir"
export USE_TMPDIR=1

if [[ "$mode" == "debug" ]]; then
    amd_render_node="/dev/dri/by-path/pci-0000:06:00.0-render"
    if [[ ! -e "$amd_render_node" ]]; then
        echo "AMD render node not found at $amd_render_node" >&2
        exit 1
    fi
    # The VM runner comes from Nix, while this host's amdgpu Mesa stack is in
    # /usr. Make its GBM backend, DRI driver, and Gallium dependencies visible
    # to QEMU's EGL-headless virgl renderer.
    export GBM_BACKENDS_PATH="/usr/lib/gbm"
    export LIBGL_DRIVERS_PATH="/usr/lib/dri"
    export LD_LIBRARY_PATH="/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

echo "Starting AR-OS VM in $mode mode..."
setsid "$runner" "$@" &
runner_pid=$!
set +e
wait "$runner_pid"
runner_status=$?
set -e
exit "$runner_status"

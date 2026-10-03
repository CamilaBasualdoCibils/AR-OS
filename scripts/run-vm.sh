#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
repository_root="$(pwd -P)"

if [[ ! -x result/bin/run-ar-os-vm ]]; then
    echo "VM runner not found; run ./scripts/build-vm.sh first." >&2
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

export NIX_DISK_IMAGE="$vm_state_dir/ar-os.qcow2"
export AROS_VM_SERIAL_LOG="$vm_state_dir/serial.log"
export SHARED_DIR="$vm_state_dir/shared"
export TMPDIR="$runtime_dir"
export USE_TMPDIR=1

# Run QEMU and its virtiofs helpers in their own process group so an interrupted
# development run cannot leave sockets or helper daemons behind.
setsid result/bin/run-ar-os-vm "$@" &
runner_pid=$!

set +e
wait "$runner_pid"
runner_status=$?
set -e
exit "$runner_status"

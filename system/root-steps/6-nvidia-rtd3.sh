#!/usr/bin/env bash
# ROOT-STEPS 17: let the RTX 3050 power off when idle again on Linux 7.3+.
# Why: kernel 7.3 broke NVIDIA's runtime-D3 detection (NVIDIA bug 7039712,
# github.com/NVIDIA/open-gpu-kernel-modules/issues/1507): the driver reports
# "Runtime D3 status: Disabled by default" and the GPU stays on (~4 W, warm).
# Fix until NVIDIA ships one: re-probe the GPU once at boot, before the login
# screen (system/usr-local-sbin/nvidia-rtd3-rebind, run by
# system/units/nvidia-rtd3-rebind.service). It does nothing when runtime D3
# already works, so it becomes harmless once the driver is fixed.
# What it does (sudo):
#   copies the script to /usr/local/sbin/nvidia-rtd3-rebind
#   copies the unit to /etc/systemd/system/nvidia-rtd3-rebind.service, enables it
# Then reboot. Check: cat /proc/driver/nvidia/gpus/0000:01:00.0/power
#   -> "Runtime D3 status: Enabled (fine-grained)"
#   and cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status -> suspended
# Undo: sudo systemctl disable nvidia-rtd3-rebind.service
#       sudo rm /etc/systemd/system/nvidia-rtd3-rebind.service /usr/local/sbin/nvidia-rtd3-rebind
#       sudo systemctl daemon-reload
# Run as your user: bash this-file
set -euo pipefail

LOG_DIR="$HOME/.local/state/dotfiles/logs"
if [[ -z ${ROOTSTEP_LOGGING:-} ]]; then
  mkdir -p "$LOG_DIR"
  LOG="$LOG_DIR/$(basename "$0" .sh)-$(date +%Y%m%d-%H%M%S).log"
  export ROOTSTEP_LOGGING="$LOG"
  exec script -q -e -f -c "$(printf '%q ' bash "$0" "$@")" "$LOG"
fi

say() { printf '\n==> %s\n' "$*"; }
[[ $EUID -ne 0 ]] || { echo "run as your normal user (not with sudo)"; exit 1; }

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_SRC="$REPO/system/usr-local-sbin/nvidia-rtd3-rebind"
UNIT_SRC="$REPO/system/units/nvidia-rtd3-rebind.service"
[[ -f $SCRIPT_SRC && -f $UNIT_SRC ]] || { echo "stop  files missing in the repo"; exit 1; }

say "Current state"
grep 'Runtime D3' /proc/driver/nvidia/gpus/*/power || echo "  (NVIDIA driver not loaded?)"

say "Installing the re-probe script and its boot service"
sudo install -m 0755 "$SCRIPT_SRC" /usr/local/sbin/nvidia-rtd3-rebind
sudo install -m 0644 "$UNIT_SRC" /etc/systemd/system/nvidia-rtd3-rebind.service
sudo systemctl daemon-reload
sudo systemctl enable nvidia-rtd3-rebind.service
echo "  ok    enabled (runs at the next boot, before the login screen)"

echo
echo "Done. Reboot, then check:  cat /proc/driver/nvidia/gpus/0000:01:00.0/power"
echo "(should say 'Runtime D3 status: Enabled (fine-grained)')."
echo "Log: ${ROOTSTEP_LOGGING/#$HOME/\~} (tell Claude you're done)"

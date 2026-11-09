#!/usr/bin/env bash
# ROOT-STEPS 2.1-2.2: NVIDIA open driver for the RTX 3050 (used via prime-run;
# Hyprland stays on the Intel iGPU), and keep nouveau out of early boot.
#
#   bash ~/dotfiles/system/root-steps/2-nvidia.sh
# Then REBOOT, then run 3-system.sh (it starts with the NVIDIA checks).
# Safe to re-run. Undo: see ROOT-STEPS.md section 2.
set -euo pipefail

# Record everything this script prints (including prompts) to a log file Claude
# can read afterwards, so nothing needs to be copy-pasted. Passwords typed at
# sudo prompts are not echoed, so they never reach the log.
LOG_DIR="$HOME/.local/state/dotfiles/logs"
if [[ -z ${ROOTSTEP_LOGGING:-} ]]; then
  mkdir -p "$LOG_DIR"
  LOG="$LOG_DIR/$(basename "$0" .sh)-$(date +%Y%m%d-%H%M%S).log"
  export ROOTSTEP_LOGGING="$LOG"
  exec script -q -e -f -c "$(printf '%q ' bash "$0" "$@")" "$LOG"
fi

say() { printf '\n==> %s\n' "$*"; }
[[ $EUID -ne 0 ]] || { echo "run as your normal user (not with sudo)"; exit 1; }
sudo -v

# --- 2.1 -------------------------------------------------------------------
say "2.1 Installing the NVIDIA driver (open kernel modules for the 'linux' kernel)"
sudo pacman -S --needed nvidia-open nvidia-utils egl-wayland libva-nvidia-driver \
  nvidia-prime mesa-utils vulkan-tools

# --- 2.2 -------------------------------------------------------------------
say "2.2 Removing the 'kms' hook so nouveau isn't loaded in early boot"
if grep -qE '^HOOKS=\(.* kms( |\))' /etc/mkinitcpio.conf; then
  [[ -e /etc/mkinitcpio.conf.bak ]] || sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
  sudo sed -i 's/^\(HOOKS=(.*\) kms\(.*\)$/\1\2/' /etc/mkinitcpio.conf
  echo "removed (original saved as /etc/mkinitcpio.conf.bak)"
else
  echo "'kms' already removed"
fi
grep '^HOOKS' /etc/mkinitcpio.conf

say "Rebuilding the boot image (UKI)"
sudo mkinitcpio -P

say "Done. Now reboot:  reboot"
echo "After rebooting, run:  bash ~/dotfiles/system/root-steps/3-system.sh"
echo "If the desktop doesn't come up: Ctrl+Alt+F3, log in, cd ~/dotfiles, claude"
echo
echo "Log saved to: ${ROOTSTEP_LOGGING/#$HOME/\~}  (tell Claude you're done; it can read this)"

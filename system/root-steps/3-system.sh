#!/usr/bin/env bash
# ROOT-STEPS 2.3-7, run after the reboot that follows 2-nvidia.sh:
#   2.3  NVIDIA checks
#   3    full-tilt performance profile (masks power-profiles-daemon)
#   4    enable multilib + full system upgrade
#   5    install all packages (install.sh --packages), then user setup (install.sh)
#   6    paccache + reflector timers
#   7    firewall (ufw)
#
#   bash ~/dotfiles/system/root-steps/3-system.sh
# Run it from inside the desktop (some checks need a graphical session).
# Safe to re-run: finished steps are skipped or re-applied harmlessly.
# Undo for each section: see ROOT-STEPS.md.
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

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
say()  { printf '\n\e[1;38;2;127;179;255m==> %s\e[0m\n' "$*"; }
ok()   { printf '  \e[32mok\e[0m    %s\n' "$*"; }
bad()  { printf '  \e[31mcheck\e[0m %s\n' "$*"; PROBLEMS=$((PROBLEMS + 1)); }
ask()  { local r; read -rp "$1 [y/N] " r; [[ $r == [yY]* ]]; }
PROBLEMS=0
[[ $EUID -ne 0 ]] || { echo "run as your normal user (not with sudo)"; exit 1; }
sudo -v

# --- 2.3 -------------------------------------------------------------------
say "2.3 NVIDIA checks"
if [[ -d /sys/module/nvidia ]]; then ok "nvidia module loaded"; else bad "nvidia module NOT loaded"; fi
if [[ -d /sys/module/nouveau ]]; then bad "nouveau is still loaded"; else ok "nouveau not loaded"; fi
p=/sys/module/nvidia_drm/parameters
[[ $(cat $p/modeset 2>/dev/null) == Y ]] && ok "nvidia_drm modeset=Y" || bad "nvidia_drm modeset is not Y"
[[ $(cat $p/fbdev 2>/dev/null) == Y ]] && ok "nvidia_drm fbdev=Y" || bad "nvidia_drm fbdev is not Y"
# PreserveVideoMemoryAllocations: 1 = on, 2 = auto (on when the kernel suspend
# notifiers are used, the default since driver 595), 0 = off.
pv="$(awk -F': ' '/PreserveVideoMemoryAllocations/{print $2}' /proc/driver/nvidia/params 2>/dev/null || true)"
kn="$(awk -F': ' '/UseKernelSuspendNotifiers/{print $2}' /proc/driver/nvidia/params 2>/dev/null || true)"
if [[ $pv == 1 || ( $pv == 2 && $kn == 1 ) ]]; then
  ok "suspend keeps GPU memory (PreserveVideoMemoryAllocations=$pv, UseKernelSuspendNotifiers=$kn)"
else
  bad "PreserveVideoMemoryAllocations=$pv, UseKernelSuspendNotifiers=$kn (see ROOT-STEPS.md 2.4)"
fi
d3="$(grep -h 'Runtime D3 status' /proc/driver/nvidia/gpus/*/power 2>/dev/null || true)"
[[ $d3 == *Enabled* ]] && ok "dGPU sleeps when idle: ${d3##*: }" || bad "runtime D3: '${d3##*: }'"
if nvidia-smi -L >/dev/null 2>&1; then ok "nvidia-smi: $(nvidia-smi -L | head -1)"; else bad "nvidia-smi failed"; fi
if [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then
  r1="$(prime-run glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer/{print $2}')"
  r2="$(glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer/{print $2}')"
  [[ $r1 == *NVIDIA* ]] && ok "prime-run renders on: $r1" || bad "prime-run renderer: '$r1'"
  [[ $r2 == *Intel* || $r2 == *Mesa* ]] && ok "default renders on: $r2" || bad "default renderer: '$r2'"
else
  echo "  (no graphical session: skipping the glxinfo renderer checks)"
fi
if ((PROBLEMS)); then
  echo
  echo "Some NVIDIA checks failed (marked 'check'). Show them to Claude."
  ask "Continue with the remaining steps anyway?" || exit 1
fi

# --- 3 ---------------------------------------------------------------------
say "3 Full-tilt performance profile"
sudo systemctl mask --now power-profiles-daemon.service
sudo install -Dm644 "$REPO/system/units/platform-profile-performance.service" \
  /etc/systemd/system/platform-profile-performance.service
sudo install -Dm644 "$REPO/system/units/99-platform-profile.rules" \
  /etc/udev/rules.d/99-platform-profile.rules
sudo systemctl daemon-reload
sudo udevadm control --reload
sudo systemctl enable platform-profile-performance.service
sudo systemctl start platform-profile-performance.service
echo "  platform_profile = $(cat /sys/firmware/acpi/platform_profile)"

# --- 4 ---------------------------------------------------------------------
say "4 Enabling multilib (32-bit libraries for Steam/Proton)"
if grep -qx multilib < <(pacman-conf --repo-list); then
  echo "  multilib already enabled"
else
  [[ -e /etc/pacman.conf.bak ]] || sudo cp /etc/pacman.conf /etc/pacman.conf.bak
  sudo sed -i '/^#\[multilib\]$/{s/^#//;n;s/^#//}' /etc/pacman.conf
  grep -qx multilib < <(pacman-conf --repo-list) || { echo "  failed to enable multilib"; exit 1; }
  echo "  enabled (original saved as /etc/pacman.conf.bak)"
fi
echo "  Full system upgrade (snap-pac takes a snapshot first). Confirm with Y:"
sudo pacman -Syu

# --- 5 ---------------------------------------------------------------------
say "5 Installing all packages"
for old in pulseaudio jack2; do
  if pacman -Q "$old" >/dev/null 2>&1; then
    echo "  NOTE: pacman will say '$old' conflicts with a PipeWire package and ask to"
    echo "        remove it. Answer y (the default N cancels the whole install)."
  fi
done
"$REPO/install.sh" --packages
say "5 User-level setup (folders, pinned clones, theme files)"
"$REPO/install.sh"

# --- 6 ---------------------------------------------------------------------
say "6 Maintenance timers"
sudo systemctl enable --now NetworkManager.service bluetooth.service
sudo install -Dm644 "$REPO/system/units/paccache.service.d/keep-2.conf" \
  /etc/systemd/system/paccache.service.d/keep-2.conf
sudo systemctl daemon-reload
sudo systemctl enable --now paccache.timer
if [[ -e /etc/xdg/reflector/reflector.conf && ! -e /etc/xdg/reflector/reflector.conf.bak ]]; then
  sudo cp /etc/xdg/reflector/reflector.conf /etc/xdg/reflector/reflector.conf.bak
fi
sudo install -Dm644 "$REPO/system/etc/reflector.conf" /etc/xdg/reflector/reflector.conf
sudo systemctl enable --now reflector.timer
echo "  Refreshing mirrors once now (can take a minute)..."
sudo systemctl start reflector.service || echo "  reflector failed; check: journalctl -u reflector"
echo "  Top mirrors:"; grep -m5 '^Server' /etc/pacman.d/mirrorlist | sed 's/^/    /'

# --- 7 ---------------------------------------------------------------------
say "7 Firewall (ufw)"
SUBNET="$(ip -4 route | awk '/proto kernel/ && /dev wl/ {print $1; exit}')"
[[ -n $SUBNET ]] || SUBNET="$(ip -4 route | awk '/proto kernel/ {print $1; exit}')"
[[ -n $SUBNET ]] || { echo "  No network found; connect to Wi-Fi and re-run."; exit 1; }
echo "  Local subnet: $SUBNET (LocalSend will only accept connections from here)"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw logging low
sudo ufw allow from "$SUBNET" to any port 53317 proto tcp comment 'LocalSend'
sudo ufw allow from "$SUBNET" to any port 53317 proto udp comment 'LocalSend'
sudo ufw --force enable
sudo systemctl enable ufw.service
sudo ufw status verbose
if curl -fsS -o /dev/null --max-time 10 https://archlinux.org; then
  ok "internet still works with the firewall on"
else
  bad "could not reach archlinux.org with the firewall on"
fi

say "All done."
echo "Show Claude the output above (especially any 'check' lines)."
echo "Not done yet on purpose: step 8 (zsh as login shell) comes with build step 3."
echo
echo "Log saved to: ${ROOTSTEP_LOGGING/#$HOME/\~}  (tell Claude you're done; it can read this)"

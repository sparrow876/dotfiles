#!/usr/bin/env bash
# ROOT-STEPS 10: login screen (SDDM). Run AFTER qylock's own scripts:
#   1) ~/.local/src/qylock/quickshell.sh   (no sudo)  -> pick "winter"
#   2) ~/.local/src/qylock/sddm.sh         (sudo)     -> 1 (Qt6), then "winter"
#   3) bash ~/dotfiles/system/root-steps/4-login.sh   (this script)
# Then reboot: SDDM shows the Winter login; pick the "Hyprland" session once
# (not "uwsm-managed"); SDDM remembers it.
# Undo: sudo systemctl disable sddm.service  (back to the text login on tty1)
set -euo pipefail

LOG_DIR="$HOME/.local/state/dotfiles/logs"
if [[ -z ${ROOTSTEP_LOGGING:-} ]]; then
  mkdir -p "$LOG_DIR"
  LOG="$LOG_DIR/$(basename "$0" .sh)-$(date +%Y%m%d-%H%M%S).log"
  export ROOTSTEP_LOGGING="$LOG"
  exec script -q -e -f -c "$(printf '%q ' bash "$0" "$@")" "$LOG"
fi

say() { printf '\n==> %s\n' "$*"; }
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  check %s\n' "$*"; PROBLEMS=$((PROBLEMS + 1)); }
PROBLEMS=0
[[ $EUID -ne 0 ]] || { echo "run as your normal user (not with sudo)"; exit 1; }

say "Checking qylock is installed"
[[ -x $HOME/.local/share/quickshell-lockscreen/lock.sh ]] && ok "lock screen installed" \
  || bad "lock screen missing: run ~/.local/src/qylock/quickshell.sh first"
[[ $(cat "$HOME/.config/qylock/theme" 2>/dev/null) == winter ]] && ok "lock theme: winter" \
  || bad "lock theme is '$(cat "$HOME/.config/qylock/theme" 2>/dev/null)' (expected winter)"
[[ -d /usr/share/sddm/themes/winter ]] && ok "SDDM theme installed" \
  || bad "SDDM theme missing: run ~/.local/src/qylock/sddm.sh first"
grep -qs '^Current=winter' /etc/sddm.conf.d/theme.conf && ok "SDDM theme selected" \
  || bad "/etc/sddm.conf.d/theme.conf doesn't select winter"
grep -qE '^-?(auth|session).*pam_gnome_keyring' /etc/pam.d/sddm && ok "keyring unlocks at login (pam_gnome_keyring in /etc/pam.d/sddm)" \
  || bad "pam_gnome_keyring missing from /etc/pam.d/sddm"
[[ -f /usr/share/wayland-sessions/hyprland.desktop ]] && ok "Hyprland session entry present" \
  || bad "no /usr/share/wayland-sessions/hyprland.desktop"
if ((PROBLEMS)); then
  echo; echo "Fix the 'check' lines above first (nothing was changed)."; exit 1
fi

say "Other display managers (only one may be enabled)"
for dm in gdm lightdm ly greetd lxdm; do
  if systemctl is-enabled "$dm.service" >/dev/null 2>&1; then
    echo "  $dm is enabled; disabling it"; sudo systemctl disable "$dm.service"
  fi
done

say "Enabling SDDM"
sudo systemctl enable sddm.service
systemctl is-enabled sddm.service

say "Done. Reboot to see the Winter login screen:  reboot"
echo "If the login screen doesn't come up: Ctrl+Alt+F3, log in, then"
echo "  sudo systemctl disable sddm.service && reboot   (back to the text login)"
echo
echo "Log saved to: ${ROOTSTEP_LOGGING/#$HOME/\~}"

#!/usr/bin/env bash
# ROOT-STEPS 16: SDDM login screen -> this repo's "strawberry-milk" theme
# (lockscreen/themes/strawberry-milk, the same theme as the lock screen).
# What it does (sudo):
#  1. copies the theme folder (Main.qml, fonts, theme.conf, bg.jpg if present)
#     to /usr/share/sddm/themes/strawberry-milk (SDDM can't read your home)
#  2. selects it in /etc/sddm.conf.d/theme.conf (backup: theme.conf.before-strawberry)
# Re-run after changing the theme (it re-copies). Run as your user: bash this-file
# Preview without logging out (a window, Esc/close quits):
#   sddm-greeter-qt6 --test-mode --theme ~/dotfiles/lockscreen/themes/strawberry-milk
# Undo: sudo cp /etc/sddm.conf.d/theme.conf.before-strawberry /etc/sddm.conf.d/theme.conf
#       (back to winter; optionally sudo rm -r /usr/share/sddm/themes/strawberry-milk)
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

SRC="$(cd "$(dirname "$0")/../.." && pwd)/lockscreen/themes/strawberry-milk"
DEST=/usr/share/sddm/themes/strawberry-milk
CONF=/etc/sddm.conf.d/theme.conf
[[ -f $SRC/Main.qml ]] || { echo "stop  theme not found at $SRC"; exit 1; }
[[ -f $SRC/bg.jpg ]] || echo "note  no bg.jpg in the theme folder: the login screen uses the pink gradient"

say "Copying the theme to $DEST"
sudo rm -rf "$DEST.new"
sudo mkdir -p "$DEST.new"
sudo cp -r "$SRC"/. "$DEST.new"/
sudo chmod -R u=rwX,go=rX "$DEST.new"
sudo rm -rf "$DEST"
sudo mv "$DEST.new" "$DEST"
echo "  ok    $(ls "$DEST" | tr '\n' ' ')"

say "Selecting it in $CONF"
[[ -e $CONF.before-strawberry ]] || { [[ -e $CONF ]] && sudo cp "$CONF" "$CONF.before-strawberry"; } || true
printf '[Theme]\nCurrent=strawberry-milk\n' | sudo tee "$CONF" >/dev/null
grep -q '^Current=strawberry-milk' "$CONF" && echo "  ok    Current=strawberry-milk"

echo
echo "Done. You'll see it at the next login screen (log out or reboot)."
echo "Log: ${ROOTSTEP_LOGGING/#$HOME/\~} (tell Claude you're done)"

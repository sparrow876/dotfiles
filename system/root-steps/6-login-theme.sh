#!/usr/bin/env bash
# ROOT-STEPS 16: SDDM login screen -> this repo's "pastel-pink" theme
# (lockscreen/themes/pastel-pink, the same theme as the lock screen).
# What it does (sudo):
#  1. copies the theme folder (Main.qml, fonts, theme.conf, bg.jpg if present)
#     to /usr/share/sddm/themes/pastel-pink (SDDM can't read your home)
#  2. selects it in /etc/sddm.conf.d/theme.conf (backup: theme.conf.before-pastel-pink)
# Re-run after changing the theme (it re-copies). Run as your user: bash this-file
# Preview without logging out (a window, Esc/close quits):
#   sddm-greeter-qt6 --test-mode --theme ~/dotfiles/lockscreen/themes/pastel-pink
# Undo: sudo cp /etc/sddm.conf.d/theme.conf.before-pastel-pink /etc/sddm.conf.d/theme.conf
#       (back to winter; optionally sudo rm -r /usr/share/sddm/themes/pastel-pink)
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

SRC="$(cd "$(dirname "$0")/../.." && pwd)/lockscreen/themes/pastel-pink"
DEST=/usr/share/sddm/themes/pastel-pink
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
[[ -e $CONF.before-pastel-pink ]] || { [[ -e $CONF ]] && sudo cp "$CONF" "$CONF.before-pastel-pink"; } || true
printf '[Theme]\nCurrent=pastel-pink\n' | sudo tee "$CONF" >/dev/null
grep -q '^Current=pastel-pink' "$CONF" && echo "  ok    Current=pastel-pink"

echo
echo "Done. You'll see it at the next login screen (log out or reboot)."
echo "Log: ${ROOTSTEP_LOGGING/#$HOME/\~} (tell Claude you're done)"

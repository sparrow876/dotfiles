#!/usr/bin/env bash
# Start Quickshell (bar, popups, notifications, ...) with the icon theme that
# matches the current palette: Papirus-Dark on dark themes, Papirus-Light on
# light ones (tray icons would vanish on a light bar otherwise).
# Quickshell reads the icon theme only at start, so theme/apply.sh restarts it
# when switching between a dark and a light theme.
#   Restart by hand: pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("~/dotfiles/scripts/qs.sh")'
theme="$(cd "$(dirname "${BASH_SOURCE[0]}")/../theme" && pwd)"
name=$(tr -d '[:space:]' < "$theme/current" 2>/dev/null)
mode=$(sed -n 's/^mode *= *"\(.*\)".*/\1/p' "$theme/palettes/$name.toml" 2>/dev/null)
if [[ $mode == light ]]; then
  export QS_ICON_THEME=Papirus-Light
else
  export QS_ICON_THEME=Papirus-Dark
fi
exec qs "$@"

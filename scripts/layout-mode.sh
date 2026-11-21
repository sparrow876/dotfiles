#!/usr/bin/env bash
# Window layout mode (bar button next to the coffee cup, or ALT + G):
#   spaced   floating rounded bar, gaps, rounded windows with shadows (default)
#   compact  i3-style: no gaps, square windows, no shadows, the bar a flat
#            strip across the top edge (max space)
#   layout-mode.sh [toggle|spaced|compact|get]     (no argument = toggle)
# The mode lives in ~/.local/state/rice/layout: Hyprland reads it when its
# config loads (hypr/conf/look.lua), the bar watches it (services/LayoutMode.qml),
# so it also survives a reboot.
set -u
state="${XDG_STATE_HOME:-$HOME/.local/state}/rice/layout"
current=$(cat "$state" 2>/dev/null || echo spaced)
[[ $current == compact ]] || current=spaced

case "${1:-toggle}" in
  get)     echo "$current"; exit 0 ;;
  spaced)  new=spaced ;;
  compact) new=compact ;;
  toggle)  [[ $current == compact ]] && new=spaced || new=compact ;;
  *)       echo "usage: $0 [toggle|spaced|compact|get]" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$state")"
printf '%s\n' "$new" > "$state"
hyprctl reload >/dev/null   # look.lua picks up the new mode
echo "$new"

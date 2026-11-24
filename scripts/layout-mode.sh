#!/usr/bin/env bash
# Window layout mode (bar button next to the coffee cup, or ALT + G):
#   spaced   floating rounded bar, gaps, rounded windows with shadows (default)
#   compact  i3-style: no gaps, square windows, no shadows, the bar a flat
#            strip across the top edge (max space)
#   layout-mode.sh [toggle|spaced|compact|get]     (no argument = toggle)
# The mode lives in ~/.local/state/rice/layout: Hyprland reads it when its
# config loads (hypr/conf/look.lua), the bar watches it (services/LayoutMode.qml)
# and animates, so it also survives a reboot. Switching is applied live
# (hyprctl eval), animated, without reloading Hyprland.
set -u
state="${XDG_STATE_HOME:-$HOME/.local/state}/rice/layout"
mkdir -p "$(dirname "$state")"
# One switch at a time: two quick presses (key + bar button) used to run
# together, and the first one's last step (shadows off) could land after the
# second one's, leaving "spaced" without shadows. The second waits, then reads
# the new state and toggles back.
exec 9>"$state.lock"
flock 9
current=$(cat "$state" 2>/dev/null || echo spaced)
[[ $current == compact ]] || current=spaced

case "${1:-toggle}" in
  get)     echo "$current"; exit 0 ;;
  spaced)  new=spaced ;;
  compact) new=compact ;;
  toggle)  [[ $current == compact ]] && new=spaced || new=compact ;;
  *)       echo "usage: $0 [toggle|spaced|compact|get]" >&2; exit 2 ;;
esac

printf '%s\n' "$new" > "$state"   # the bar starts its 0.32 s animation now
[[ $new == "$current" ]] && { echo "$new"; exit 0; }

# Apply live instead of `hyprctl reload` (smooth): the gaps change once and
# Hyprland's windowsMove animation (0.3 s) glides the windows; the corner
# radius isn't animatable, so it steps over the same 0.3 s. Values = colors.lua
# (gaps_in 6, gaps_out 12, rounding 14); look.lua reads the state file on the
# next config load, so a later reload keeps the mode.
set_cfg() { hyprctl eval "hl.config($1)" >/dev/null; }
if [[ $new == compact ]]; then
  set_cfg '{ general = { gaps_in = 0, gaps_out = 0 } }'
  for r in 12 9 6 4 2 0; do set_cfg "{ decoration = { rounding = $r } }"; sleep 0.05; done
  set_cfg '{ decoration = { shadow = { enabled = false } } }'   # windows touch now
else
  set_cfg '{ decoration = { shadow = { enabled = true } } }'
  set_cfg '{ general = { gaps_in = 6, gaps_out = 12 } }'
  for r in 2 4 6 9 12 14; do set_cfg "{ decoration = { rounding = $r } }"; sleep 0.05; done
fi
echo "$new"

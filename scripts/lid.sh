#!/usr/bin/env bash
# Laptop lid and screen power. Called by Hyprland's lid binds (keybinds.lua) and
# hypridle (hypridle.conf); logind decides lock vs suspend (10-lid.conf).
#   lid.sh close     lid closed: laptop panel off. With another monitor on, the
#                    panel is disabled completely, so workspaces and the cursor
#                    move to that monitor; alone, it's only switched off
#                    (Hyprland always needs one output).
#   lid.sh open      lid opened: panel enabled and on again
#   lid.sh screens-on   after idle / sleep: every screen on, except the laptop
#                    panel while the lid is closed (no glowing closed lid)
set -u
panel=eDP-1

lid_closed() { grep -qs closed /proc/acpi/button/lid/*/state; }
others_on() {
  hyprctl -j monitors | jq -e --arg p "$panel" '[.[] | select(.name != $p)] | length > 0' >/dev/null
}

case "${1:-}" in
  close)
    if others_on; then
      hyprctl dispatch "function() hl.monitor({ output = \"$panel\", disabled = true }) end" >/dev/null
    else
      hyprctl dispatch "hl.dsp.dpms({ action = \"off\", monitor = \"$panel\" })" >/dev/null
    fi ;;
  open)
    hyprctl dispatch "function() hl.monitor({ output = \"$panel\", disabled = false }) end" >/dev/null
    hyprctl dispatch "hl.dsp.dpms({ action = \"on\", monitor = \"$panel\" })" >/dev/null ;;
  screens-on)
    if lid_closed; then
      hyprctl -j monitors | jq -r --arg p "$panel" '.[] | select(.name != $p) | .name' | while read -r m; do
        hyprctl dispatch "hl.dsp.dpms({ action = \"on\", monitor = \"$m\" })" >/dev/null
      done
    else
      hyprctl dispatch 'hl.dsp.dpms({ action = "on" })' >/dev/null
    fi ;;
  *) echo "usage: $0 close|open|screens-on" >&2; exit 2 ;;
esac

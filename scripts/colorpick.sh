#!/usr/bin/env bash
# Color picker (ALT + SHIFT + C): pick a pixel, hex copied to the clipboard,
# notification with a swatch, hex and rgb.
set -u
hex=$(hyprpicker -a -f hex 2>/dev/null)
[[ -z $hex ]] && exit 0
hex=${hex^^}
r=$((16#${hex:1:2})) g=$((16#${hex:3:2})) b=$((16#${hex:5:2}))
swatch="${XDG_RUNTIME_DIR:-/tmp}/colorpick-swatch.png"
magick -size 96x96 "xc:$hex" "$swatch"
notify-send -a "Color picker" -i "$swatch" "$hex" "rgb($r, $g, $b) · copied to clipboard"

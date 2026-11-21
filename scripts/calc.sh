#!/usr/bin/env bash
# Calculator (ALT + =): rofi-calc (libqalculate) in the shared rofi style.
# Type an expression and the answer appears as you type:
#   2*pi*4    15% of 240    sqrt(2)    3 days in hours    100 km/h to m/s
#   5 usd to inr   (currency rates are downloaded by libqalculate when used)
# Enter copies the result to the clipboard. Esc closes.
set -u
if [[ ! -e /usr/lib/rofi/calc.so ]]; then
  notify-send -a Calculator -i dialog-warning "Calculator not installed" "sudo pacman -S rofi-calc"
  exit 1
fi
exec rofi -show calc -modi calc -no-show-match -no-sort -no-history \
  -calc-command "printf '%s' '{result}' | wl-copy" \
  -theme-str 'entry { placeholder: "Calculate: 2*pi*4, 15% of 240, 5 usd to inr"; } listview { lines: 4; }'

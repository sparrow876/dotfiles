#!/usr/bin/env bash
# Calculator (ALT + =): rofi-calc (libqalculate) in the shared rofi style.
# Type an expression and the answer appears as you type:
#   2*pi*4    15% * 240    240 + 15%    15/240 to %    sqrt(2)
#   3 days to hours    100 km/h to m/s    5 usd to inr   (currency rates are
#   downloaded by libqalculate when used)
# Conversions use "to", not "in" ("in" is inches), and percentages need an
# operator: "15% of 240" means something else to libqalculate (rem(15, 1 B)).
# Every example here was checked with `qalc -t`.
# Enter copies the result to the clipboard. Esc closes.
set -u
if ! compgen -G "/usr/lib/rofi/*calc.so" >/dev/null; then   # Arch: /usr/lib/rofi/libcalc.so
  notify-send -a Calculator -i dialog-warning "Calculator not installed" "sudo pacman -S rofi-calc"
  exit 1
fi
exec rofi -show calc -modi calc -no-show-match -no-sort -no-history \
  -calc-command "printf '%s' '{result}' | wl-copy" \
  -theme-str 'entry { placeholder: "Calculate: 2*pi*4, 15% * 240, 5 usd to inr"; } listview { lines: 4; }'

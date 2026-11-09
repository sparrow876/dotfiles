#!/usr/bin/env bash
# Screenshots. Saved to ~/Pictures/Screenshots/YYYY-MM-DD_HH-MM-SS.png AND
# copied to the clipboard, then a notification with a thumbnail, "Edit" (satty)
# and "Open folder".
#   screenshot.sh region   Print / ALT + SHIFT + S  (screen freezes while selecting)
#   screenshot.sh full     SHIFT + Print            (the focused monitor)
#   screenshot.sh window   ALT + Print              (the active window)
set -u
source "$(dirname "$0")/theme-colors.sh"   # generated: theme colors for slurp
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
n=2
while [[ -e $file ]]; do file="${file%.png}"; file="${file%-[0-9]*}-$n.png"; n=$((n + 1)); done

case "${1:-region}" in
  region)
    # Freeze the screen (hyprpicker draws a still frame) while slurp selects
    hyprpicker -r -z >/dev/null 2>&1 & freeze=$!
    sleep 0.15
    geom=$(slurp -d "${SLURP_ARGS[@]}")
    kill $freeze 2>/dev/null
    [[ -z $geom ]] && exit 0          # cancelled with Esc
    sleep 0.05
    grim -g "$geom" "$file" ;;
  full)
    mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    grim -o "$mon" "$file" ;;
  window)
    geom=$(hyprctl activewindow -j | jq -r 'if .at then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')
    [[ -z $geom ]] && { notify-send -a Screenshot "No active window"; exit 1; }
    grim -g "$geom" "$file" ;;
  *) echo "usage: $0 region|full|window" >&2; exit 2 ;;
esac

[[ -s $file ]] || exit 1
wl-copy --type image/png < "$file"
"$(dirname "$0")/notify-file.sh" Screenshot "Screenshot saved" \
  "$(basename "$file") · copied to clipboard" "$file" "$file" edit folder

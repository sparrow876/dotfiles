#!/usr/bin/env bash
# Notification for a saved file with buttons, handling the click in the
# background so callers don't wait.
#   notify-file.sh <app> <title> <body> <file> <icon> <action>...
# actions: edit (satty), open (default app / mpv), folder (file manager)
app=$1 title=$2 body=$3 file=$4 icon=$5; shift 5
args=(-A "default=Open")   # clicking the notification itself opens the file
for a in "$@"; do
  case $a in
    edit)   args+=(-A "edit=Edit") ;;
    open)   args+=(-A "open=Open") ;;
    folder) args+=(-A "folder=Open folder") ;;
  esac
done
(
  # notify-send -A waits until a button is pressed or the notification closes;
  # give up after an hour so old ones don't leave processes behind
  choice=$(timeout 1h notify-send -a "$app" -i "$icon" "${args[@]}" "$title" "$body")
  case $choice in
    edit)   satty --filename "$file" --output-filename "$file" --early-exit --copy-command wl-copy ;;
    open|default) xdg-open "$file" ;;
    folder) xdg-open "$(dirname "$file")" ;;
  esac
) >/dev/null 2>&1 &
disown

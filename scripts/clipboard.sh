#!/usr/bin/env bash
# Clipboard history picker (ALT + C): cliphist + rofi, newest first.
#   Enter                 copy the entry back to the clipboard
#   Shift + Delete        delete the entry (the list reopens)
#   Ctrl + Shift + Delete clear the whole history (asks first)
# Images show a small thumbnail (cached in ~/.cache/cliphist-thumbs).
# History is recorded by the cliphist watchers started in hypr/conf/autostart.lua
# (max 200 entries).
set -u

thumbs="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist-thumbs"
mkdir -p "$thumbs"

# Build the rofi list: "<id>\t<label>\0icon\x1f<thumbnail>" for images
build_list() {
  cliphist list | while IFS=$'\t' read -r id content; do
    if [[ $content =~ ^\[\[\ binary\ data\ ([0-9.]+\ [KMG]?i?B)\ ([a-z]+)\ ([0-9]+x[0-9]+)\ \]\] ]]; then
      size="${BASH_REMATCH[1]}"; fmt="${BASH_REMATCH[2]}"; dims="${BASH_REMATCH[3]}"
      thumb="$thumbs/$id.png"
      if [[ ! -s $thumb ]]; then
        # cliphist needs the whole "id<TAB>content" line, not just the id
        printf '%s\t%s\n' "$id" "$content" | cliphist decode | magick - -thumbnail 96x96 "$thumb" 2>/dev/null
      fi
      printf '%s\t󰋩  Image %s · %s %s\0icon\x1f%s\n' "$id" "${dims/x/×}" "${fmt^^}" "$size" "$thumb"
    else
      printf '%s\t%s\n' "$id" "$content"
    fi
  done
}

while true; do
  choice=$(build_list | rofi -dmenu -i -p "" \
      -display-columns 2 -display-column-separator $'\t' \
      -show-icons -theme-str 'element-icon { size: 40px; } entry { placeholder: "Search clipboard"; }' \
      -mesg "Enter copy · Shift+Del delete · Ctrl+Shift+Del clear all" \
      -kb-delete-entry "" -kb-custom-1 "Shift+Delete" -kb-custom-2 "Control+Shift+Delete")
  code=$?

  case $code in
    0)   # copy
      [[ -n $choice ]] && cliphist decode <<<"$choice" | wl-copy
      exit 0 ;;
    10)  # delete this entry, then show the list again
      [[ -n $choice ]] && cliphist delete <<<"$choice"
      rm -f "$thumbs/${choice%%$'\t'*}.png"
      continue ;;
    11)  # clear everything (confirm)
      answer=$(printf 'No, keep it\nYes, clear all clipboard history\n' |
               rofi -dmenu -i -p "" -mesg "Clear the whole clipboard history?" \
                    -theme-str 'listview { lines: 2; } inputbar { enabled: false; }')
      if [[ $answer == Yes* ]]; then
        cliphist wipe
        rm -f "$thumbs"/*.png
        notify-send -a "Clipboard" -i edit-clear-all "Clipboard history cleared"
        exit 0
      fi
      continue ;;
    *)   exit 0 ;;   # Esc
  esac
done

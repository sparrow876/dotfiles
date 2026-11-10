#!/usr/bin/env bash
# OCR (ALT + O): freeze the screen, select a region, read its text with
# tesseract (English), copy it to the clipboard, notify with the first 80 chars.
set -u
source "$(dirname "$0")/theme-colors.sh"   # generated: theme colors for slurp
hyprpicker -r -z >/dev/null 2>&1 & freeze=$!
sleep 0.15
geom=$(slurp -d "${SLURP_ARGS[@]}")
kill $freeze 2>/dev/null
[[ -z $geom ]] && exit 0
sleep 0.05
# 2x upscale helps tesseract with small UI text
text=$(grim -g "$geom" - | magick - -resize 200% png:- | tesseract - - -l eng --psm 6 2>/dev/null | sed -e 's/[[:space:]]*$//' -e '/^$/N;/^\n$/D')
if [[ -z ${text//[[:space:]]/} ]]; then
  notify-send -a OCR -i edit-find "No text found" "Try selecting a larger or clearer area."
  exit 1
fi
printf '%s' "$text" | wl-copy
preview=$(printf '%s' "$text" | tr '\n' ' ' | cut -c1-80)
[[ ${#text} -gt 80 ]] && preview+="…"
# notification bodies understand markup: show OCR'd <, > and & literally
preview=${preview//&/&amp;}; preview=${preview//</&lt;}; preview=${preview//>/&gt;}
notify-send -a OCR -i edit-copy "Text copied" "$preview"

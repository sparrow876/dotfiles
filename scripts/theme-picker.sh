#!/usr/bin/env bash
# Theme selector (ALT + T): rofi list of theme/palettes/*.toml with a colour
# swatch per theme; Enter applies it (theme/apply.sh).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/theme-swatches"
mkdir -p "$cache"
current=$(tr -d '[:space:]' < "$ROOT/theme/current")

list() {
  for f in "$ROOT"/theme/palettes/*.toml; do
    n=$(basename "$f" .toml)
    get() { sed -n "s/^$1 *= *\"\([^\"]*\)\".*/\1/p" "$f"; }
    swatch="$cache/$n.png"
    # 5 vertical stripes: surface, overlay, accent, highlight, text
    if [[ ! -s $swatch || $f -nt $swatch ]]; then
      magick -size 18x90 "xc:$(get surface)" "xc:$(get overlay)" "xc:$(get lightblue)" "xc:$(get ice)" "xc:$(get text)" +append \
        -resize 90x90! \( +clone -alpha extract -draw 'fill black polygon 0,0 0,14 14,0 fill white circle 14,14 14,0' \
        \( +clone -flip \) -compose Multiply -composite \( +clone -flop \) -compose Multiply -composite \) \
        -alpha off -compose CopyOpacity -composite "$swatch" 2>/dev/null
    fi
    mark=""; [[ $n == "$current" ]] && mark="  ✓"
    printf '%s\t%s<span size="small" alpha="60%%">%s</span>\0icon\x1f%s\n' "$n" "$(get name)" "$mark" "$swatch"
  done
}

choice=$(list | rofi -dmenu -i -no-custom -p "" -markup-rows -show-icons \
  -display-columns 2 -display-column-separator $'\t' \
  -theme-str 'element-icon { size: 36px; } entry { placeholder: "Choose a theme"; } listview { lines: 8; }')
[[ -z $choice ]] && exit 0
exec "$ROOT/theme/apply.sh" "${choice%%$'\t'*}"

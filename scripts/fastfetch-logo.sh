#!/usr/bin/env bash
# The picture fastfetch shows in kitty (instead of the Arch logo).
#
#   scripts/fastfetch-logo.sh IMAGE [CROP]   use a new picture
#   scripts/fastfetch-logo.sh                rebuild from the saved copy
#                                            (theme/apply.sh does this, so the
#                                            outline follows the theme)
#
# IMAGE is copied to ~/.config/fastfetch/logo-source.png (the copy kept with
# fastfetch's config) and turned into logo.png: a portrait card, 558x640
# (= 30 x 15 terminal cells at kitty's 13 pt font), rounded corners and a
# thin outline in the theme's accent color. CROP is an ImageMagick geometry
# (WxH+X+Y) picking the part of the image to use; without it the middle is
# used. The crop is remembered in logo.crop.
# Both PNGs stay out of git (.gitignore: *.png): pictures aren't committed.
# Without logo.png, zsh falls back to the small Arch logo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/fastfetch/.config/fastfetch"
SRC="$DIR/logo-source.png"
CROPFILE="$DIR/logo.crop"
OUT="$DIR/logo.png"
W=558 H=640 RADIUS=36

if [[ $# -ge 1 ]]; then
  [[ -f $1 ]] || { echo "fastfetch-logo: no such file: $1" >&2; exit 1; }
  magick "$1" "$SRC"                     # converts too, if it isn't a PNG
  if [[ -n ${2:-} ]]; then echo "$2" >"$CROPFILE"; else rm -f "$CROPFILE"; fi
fi
[[ -f $SRC ]] || exit 0                  # nothing chosen yet: keep the Arch logo

theme="$(tr -d '[:space:]' <"$ROOT/theme/current" 2>/dev/null || true)"
accent="$(sed -nE 's/^lightblue[[:space:]]*=[[:space:]]*"(#[0-9a-fA-F]{6})".*/\1/p' \
          "$ROOT/theme/palettes/${theme:-blue-ice}.toml" 2>/dev/null)"
accent=${accent:-#7fb3ff}

crop=()
[[ -s $CROPFILE ]] && crop=(-crop "$(<"$CROPFILE")" +repage)

tmp="$(mktemp --suffix=.png)"
trap 'rm -f "$tmp"' EXIT
magick "$SRC" "${crop[@]}" \
  -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" \
  \( +clone -alpha extract -fill black -colorize 100 -fill white \
     -draw "roundrectangle 0,0 $((W - 1)),$((H - 1)) $RADIUS,$RADIUS" \) \
  -alpha off -compose CopyOpacity -composite -compose Over \
  -fill none -stroke "$accent" -strokewidth 3 \
  -draw "roundrectangle 1,1 $((W - 2)),$((H - 2)) $((RADIUS - 1)),$((RADIUS - 1))" \
  "$tmp"
chmod 644 "$tmp"
mv "$tmp" "$OUT"
trap - EXIT
echo "fastfetch-logo: ${OUT/#$HOME/\~} (outline $accent)"

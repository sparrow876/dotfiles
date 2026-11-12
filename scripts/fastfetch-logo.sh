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
# (= 30 x 15 terminal cells at kitty's 13 pt font), recolored in the theme's
# colors with a glow, scanlines, vignette and grain, rounded corners and a
# thin accent outline (steps listed below). CROP is an ImageMagick geometry
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
palette="$ROOT/theme/palettes/${theme:-blue-ice}.toml"
color() {   # color NAME FALLBACK: a color from the active palette
  local c
  c="$(sed -nE "s/^$1[[:space:]]*=[[:space:]]*\"(#[0-9a-fA-F]{6})\".*/\1/p" "$palette" 2>/dev/null)"
  echo "${c:-$2}"
}
dark=$(color base '#0d1b2a') mid=$(color blue '#415a77')
accent=$(color lightblue '#7fb3ff') light=$(color text '#f4f8ff')

crop=()
[[ -s $CROPFILE ]] && crop=(-crop "$(<"$CROPFILE")" +repage)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
tmp="$work/logo.png"

# The look, step by step:
#  1. crop + fill the 558x640 card
#  2. recolor: grayscale, more contrast, then map dark->light onto the theme's
#     own colors (base -> blue -> lightblue -> text), a "gradient map"
#  3. chromatic split: red shifted 2 px right, blue 2 px left (lens fringe)
#  4. CRT scanlines: every 3rd row a little darker
#  5. vignette: corners fade towards dark
#  6. bloom: the brightest parts glow softly
#  7. film grain
#  8. rounded corners + thin accent outline
magick -size 1x86 gradient:"$dark-$mid" -size 1x85 gradient:"$mid-$accent" \
       -size 1x85 gradient:"$accent-$light" -append -rotate -90 "$work/ramp.png"
magick -size 1x3 xc:white -fill gray82 -draw 'point 0,2' -write mpr:row +delete \
       -size "${W}x${H}" tile:mpr:row "$work/scan.png"
magick -size "${W}x${H}" radial-gradient:white-gray25 -level 0,80% "$work/vignette.png"

magick "$SRC" "${crop[@]}" \
  -resize "${W}x${H}^" -gravity center -extent "${W}x${H}" +repage \
  -colorspace gray -auto-level -sigmoidal-contrast 5,45% \
  "$work/ramp.png" -clut -write mpr:toned \
  \( -clone 0 -channel R -separate +channel -roll +2+0 \) \
  \( -clone 0 -channel G -separate +channel \) \
  \( -clone 0 -channel B -separate +channel -roll -2+0 \) \
  -delete 0 -set colorspace sRGB -combine \
  "$work/scan.png" -compose Multiply -composite \
  "$work/vignette.png" -compose Multiply -composite \
  \( +clone -threshold 70% -blur 0x10 -evaluate multiply 0.35 \) -compose Screen -composite \
  \( -size "${W}x${H}" xc:gray50 -seed 7 +noise Gaussian -colorspace gray -evaluate multiply 0.9 \) \
  -compose SoftLight -composite \
  \( +clone -alpha extract -fill black -colorize 100 -fill white \
     -draw "roundrectangle 0,0 $((W - 1)),$((H - 1)) $RADIUS,$RADIUS" \) \
  -alpha off -compose CopyOpacity -composite -compose Over \
  -fill none -stroke "$accent" -strokewidth 3 \
  -draw "roundrectangle 1,1 $((W - 2)),$((H - 2)) $((RADIUS - 1)),$((RADIUS - 1))" \
  "$tmp"
chmod 644 "$tmp"
mv "$tmp" "$OUT"
echo "fastfetch-logo: ${OUT/#$HOME/\~} (outline $accent)"

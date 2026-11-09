#!/usr/bin/env bash
# Render every color/theme file in the repo from theme/palette.toml.
#
# How it works:
#   theme/templates/<path>.tmpl  ->  <repo>/<path>
# e.g. theme/templates/kitty/.config/kitty/colors.conf.tmpl
#      becomes kitty/.config/kitty/colors.conf
#
# Placeholders available in templates (for every palette key):
#   {{name}}        value as written, e.g. #7fb3ff  or  JetBrainsMono Nerd Font
#   {{name.hex}}    color without '#', e.g. 7fb3ff
#   {{name.rgb}}    decimal triple, e.g. 127, 179, 255
#   {{name.alpha}}  for 0..1 numbers: alpha as 2 hex digits, e.g. 0.75 -> bf
#
# Unknown placeholders are reported and make the script fail, so typos can't
# silently produce broken configs. Safe to run any time; output is deterministic.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PALETTE="$ROOT/theme/palette.toml"
TEMPLATES="$ROOT/theme/templates"

sedscript="$(mktemp)"
trap 'rm -f "$sedscript"' EXIT

escape() { printf '%s' "$1" | sed -e 's/[\\|&]/\\&/g'; }

# Parse `key = "value"` lines (ignores [sections], comments and blanks).
while IFS= read -r line; do
  [[ $line =~ ^[[:space:]]*([a-z_][a-z0-9_]*)[[:space:]]*=[[:space:]]*\"([^\"]*)\" ]] || continue
  key="${BASH_REMATCH[1]}"
  val="${BASH_REMATCH[2]}"
  printf 's|{{%s}}|%s|g\n' "$key" "$(escape "$val")" >>"$sedscript"
  if [[ $val =~ ^#([0-9a-fA-F]{6})$ ]]; then
    hex="${BASH_REMATCH[1],,}"
    rgb="$((16#${hex:0:2})), $((16#${hex:2:2})), $((16#${hex:4:2}))"
    printf 's|{{%s.hex}}|%s|g\n' "$key" "$hex" >>"$sedscript"
    printf 's|{{%s.rgb}}|%s|g\n' "$key" "$rgb" >>"$sedscript"
  elif [[ $val =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]]; then
    alpha="$(awk -v a="$val" 'BEGIN { printf "%02x", int(a * 255 + 0.5) }')"
    printf 's|{{%s.alpha}}|%s|g\n' "$key" "$alpha" >>"$sedscript"
  fi
done <"$PALETTE"

count=0
while IFS= read -r -d '' tmpl; do
  rel="${tmpl#"$TEMPLATES"/}"
  out="$ROOT/${rel%.tmpl}"
  mkdir -p "$(dirname "$out")"
  rendered="$(sed -f "$sedscript" "$tmpl")"
  if leftover="$(grep -o '{{[^}]*}}' <<<"$rendered" | sort -u)" && [[ -n $leftover ]]; then
    echo "render.sh: unknown placeholder(s) in $rel:" >&2
    echo "$leftover" >&2
    exit 1
  fi
  printf '%s\n' "$rendered" >"$out"
  echo "rendered ${out#"$ROOT"/}"
  count=$((count + 1))
done < <(find "$TEMPLATES" -type f -name '*.tmpl' -print0 | sort -z)

echo "render.sh: $count file(s) written."

#!/usr/bin/env bash
# Give qimgv (image viewer) the active theme's colors.
# qimgv saves its colors to ~/.config/qimgv/theme.conf every time it exits, so
# that file can't be a stow symlink: this script copies the rendered
# qimgv/theme.conf there and switches qimgv to "custom colors" mode.
# Run by install.sh (step qt) and theme/apply.sh. Takes effect the next time
# qimgv opens; if it's open right now, close it and run this again.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$ROOT/qimgv/theme.conf"
dir="$HOME/.config/qimgv"
[[ -f $src ]] || { echo "qimgv: $src missing (run theme/render.sh)" >&2; exit 1; }

if [[ -n $(ps -C qimgv -o pid=) ]]; then
  echo "qimgv is open: it will overwrite its colors when it closes. Close it, then run theme/qimgv.sh." >&2
  exit 1
fi

mkdir -p "$dir"
grep -v '^#' "$src" > "$dir/theme.conf"   # QSettings: no # comments

# Use theme.conf, not the Qt palette
conf="$dir/qimgv.conf"
if [[ -f $conf ]] && grep -q '^useSystemColorScheme=' "$conf"; then
  sed -i 's/^useSystemColorScheme=.*/useSystemColorScheme=false/' "$conf"
elif [[ -f $conf ]] && grep -q '^\[General\]' "$conf"; then
  sed -i '/^\[General\]/a useSystemColorScheme=false' "$conf"
else
  printf '[General]\nuseSystemColorScheme=false\n' >> "$conf"
fi
echo "qimgv: colors from $(sed -n 's/^# qimgv colors for the \([^.]*\) theme\..*/\1/p' "$src")"

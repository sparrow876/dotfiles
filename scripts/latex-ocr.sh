#!/usr/bin/env bash
# LaTeX OCR (ALT + SHIFT + O): freeze the screen, select an equation, turn it
# into LaTeX code with pix2tex (offline), copy it, notify with the code.
# Needs the one-time setup: scripts/latex-ocr/setup.sh (private Python venv).
# Takes a few seconds per equation (loading PyTorch + the model, on the CPU).
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
py="${XDG_DATA_HOME:-$HOME/.local/share}/latex-ocr/venv/bin/python"
note() { notify-send -a "LaTeX OCR" "$@"; }

if [[ ! -x $py ]]; then
  note -i dialog-warning "LaTeX OCR isn't set up yet" "Run ~/dotfiles/scripts/latex-ocr/setup.sh in a terminal once."
  exit 1
fi

source "$here/theme-colors.sh"   # generated: theme colors for slurp
hyprpicker -r -z >/dev/null 2>&1 & freeze=$!
sleep 0.15
geom=$(slurp -d "${SLURP_ARGS[@]}")
kill $freeze 2>/dev/null
[[ -z $geom ]] && exit 0
sleep 0.05

img=$(mktemp --suffix=.png)
err=$(mktemp)
trap 'rm -f "$img" "$err"' EXIT
grim -g "$geom" "$img"

id=$(notify-send -p -a "LaTeX OCR" -i accessories-calculator -t 30000 "Reading the equation…" "This takes a few seconds.")
latex=$("$py" -I "$here/latex-ocr/latex_ocr.py" "$img" 2>"$err" | tail -n1)

if [[ -z ${latex//[[:space:]]/} ]]; then
  reason=$(grep -v '^\s*$' "$err" | tail -n1 | cut -c1-120)
  reason=${reason//&/&amp;}; reason=${reason//</&lt;}; reason=${reason//>/&gt;}
  notify-send -r "$id" -a "LaTeX OCR" -i dialog-error "No LaTeX recognised" \
    "${reason:-Try a tighter box around one equation.}"
  exit 1
fi

printf '%s' "$latex" | wl-copy
preview=$(printf '%s' "$latex" | cut -c1-160)
[[ ${#latex} -gt 160 ]] && preview+="…"
# notification bodies understand markup: show <, > and & literally
preview=${preview//&/&amp;}; preview=${preview//</&lt;}; preview=${preview//>/&gt;}
notify-send -r "$id" -a "LaTeX OCR" -i edit-copy "LaTeX copied" "$preview"

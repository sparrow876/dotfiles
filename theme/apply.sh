#!/usr/bin/env bash
# Switch the whole desktop to another theme and reload what's running.
#   theme/apply.sh                 list themes (* = active)
#   theme/apply.sh <name>          e.g. catppuccin-mocha, blue-ice
# What changes: Hyprland borders, the bar/popups/panels (Quickshell), rofi,
# kitty, starship, fzf, bat, lazygit, fastfetch, slurp selections, and the
# GTK/Qt dark/light preference. Neovim, Nautilus and zathura stay Nord, the
# lock/login screen keeps its qylock theme.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/theme"

current=$(tr -d '[:space:]' < current)
if [[ $# -eq 0 ]]; then
  for f in palettes/*.toml; do
    n=$(basename "$f" .toml)
    title=$(sed -n 's/^name *= *"\(.*\)".*/\1/p' "$f")
    mode=$(sed -n 's/^mode *= *"\(.*\)".*/\1/p' "$f")
    printf '%s %-24s %s (%s)\n' "$([[ $n == "$current" ]] && echo '*' || echo ' ')" "$n" "$title" "$mode"
  done
  exit 0
fi

name=$1
[[ -f palettes/$name.toml ]] || { echo "No theme '$name'. Run $0 to list them." >&2; exit 1; }
mode=$(sed -n 's/^mode *= *"\(.*\)".*/\1/p' "palettes/$name.toml")
title=$(sed -n 's/^name *= *"\(.*\)".*/\1/p' "palettes/$name.toml")

# A theme switch reloads the whole bar (Quickshell). Don't do that in the middle
# of a screen recording or with replay mode on.
if pidof gpu-screen-recorder >/dev/null; then
  command -v notify-send >/dev/null && notify-send -a Theme -i dialog-warning \
    "Theme not changed" "Stop the screen recording / replay mode first." || true
  echo "A screen recording or replay mode is running; stop it first." >&2
  exit 1
fi

old_mode=$(sed -n 's/^mode *= *"\(.*\)".*/\1/p' "palettes/$current.toml" 2>/dev/null)
echo "$name" > current
if ! ./render.sh >/dev/null; then
  # Don't leave the desktop half-switched: go back to the previous theme
  echo "$current" > current
  ./render.sh >/dev/null || true
  command -v notify-send >/dev/null && notify-send -u critical -a Theme -i dialog-error \
    "Theme '$title' could not be applied" "Kept $current. Run theme/apply.sh $name in a terminal to see why." || true
  echo "render.sh failed for '$name'; went back to '$current'." >&2
  exit 1
fi

# Reload running apps (each step is optional: skipped if the app isn't running)
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null || true                    # borders, shadows
fi
pkill -USR1 -x kitty 2>/dev/null || true               # kitty re-reads colors.conf
"$ROOT/theme/qt.sh" >/dev/null || true                  # Qt apps (next launch)
command -v bat >/dev/null && bat cache --build >/dev/null 2>&1 || true
if [[ $mode != "$old_mode" ]] && pgrep -x qs >/dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  # dark <-> light: Quickshell must restart to pick the matching icon theme
  pkill -x qs; sleep 0.3
  hyprctl dispatch 'hl.dsp.exec_cmd("'"$ROOT"'/scripts/qs.sh")' >/dev/null || true
else
  touch "$ROOT/quickshell/.config/quickshell/Theme.qml"  # Quickshell hot-reloads
fi
if command -v gsettings >/dev/null && [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
  if [[ $mode == light ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Light'
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
  fi
fi
command -v notify-send >/dev/null && notify-send -a Theme -i preferences-desktop-theme \
  "Theme: $title" "New terminals and shells pick it up when opened." || true
echo "Applied $name ($title, $mode)."

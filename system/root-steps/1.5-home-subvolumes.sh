#!/usr/bin/env bash
# ROOT-STEPS 1.5: turn big/throwaway folders into their own btrfs subvolumes so
# /home snapshots skip them. No sudo needed.
#
# Run from a TTY (Ctrl+Alt+F3) while the desktop is NOT running (log out of
# Hyprland first), so nothing is writing to ~/.cache:
#   bash ~/dotfiles/system/root-steps/1.5-home-subvolumes.sh
# Existing contents are copied into the new subvolume. Safe to re-run.
# Undo (per folder): see ROOT-STEPS.md 1.5.
set -euo pipefail

[[ $EUID -ne 0 ]] || { echo "run as your normal user (not with sudo)"; exit 1; }
if pgrep -x -u "$USER" Hyprland >/dev/null; then
  echo "Hyprland is running. Log out of the desktop first, then run this from a TTY."
  exit 1
fi

mksubvol() {
  local d="$1"
  if [[ -d $d && $(stat -c %i "$d") == 256 ]]; then
    echo "ok    $d (already a subvolume)"
    return
  fi
  if [[ -e $d.old ]]; then
    echo "stop  $d.old exists from an earlier run; check it, then remove it and re-run"
    exit 1
  fi
  [[ -e $d ]] && mv "$d" "$d.old"
  mkdir -p "$(dirname "$d")"
  btrfs subvolume create "$d" >/dev/null
  if [[ -d $d.old ]]; then
    cp -a --reflink=always "$d.old/." "$d/"   # instant copy on btrfs; .old kept if it fails
    rm -rf "$d.old"
  fi
  echo "made  $d"
}

mksubvol "$HOME/.cache"               # also holds the Google Drive (rclone) cache + thumbnails
mksubvol "$HOME/Downloads"
mksubvol "$HOME/Videos/Recordings"
mksubvol "$HOME/.local/share/Steam"   # Steam + its default library; before installing Steam

echo
echo "Done. You can log back into the desktop."

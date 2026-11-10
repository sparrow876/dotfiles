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
  # Leftover from an earlier run whose copy failed: your files are still in .old
  if [[ -e $d.old ]]; then
    if [[ -d $d && $(stat -c %i "$d") == 256 ]]; then
      echo "stop  $d.old still holds your files from an earlier run. Finish it with:"
      echo "      cp -a --reflink=always \"$d.old/.\" \"$d/\" && rm -rf \"$d.old\""
    else
      echo "stop  $d.old exists from an earlier run; check it, then remove it and re-run"
    fi
    exit 1
  fi
  if [[ -d $d && $(stat -c %i "$d") == 256 ]]; then
    echo "ok    $d (already a subvolume)"
    return
  fi
  [[ -e $d ]] && mv "$d" "$d.old"
  mkdir -p "$(dirname "$d")"
  btrfs subvolume create "$d" >/dev/null
  if [[ -d $d.old ]]; then
    # instant copy on btrfs; on failure .old is kept and the script stops
    if ! cp -a --reflink=always "$d.old/." "$d/"; then
      echo "stop  copying $d.old into the new subvolume failed; your files are still in $d.old"
      exit 1
    fi
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

#!/usr/bin/env bash
# ROOT-STEPS 15: make "Move to Trash" work in the folders that are their own
# btrfs subvolumes (Downloads, Videos/Recordings, .cache, Steam; made in 1.5).
# Why: a subvolume has its own device number, and GLib/Nautilus only trash
# across devices on a real mount (otherwise: "Trashing on system internal
# mounts is not supported", and Nautilus offers to delete permanently).
# Fix: mount each subvolume at its own path from /etc/fstab. Nothing moves;
# it's the same folder. Each then keeps its own trash (<folder>/.Trash-<uid>),
# which Nautilus's Trash shows together with the normal one.
#   x-gvfs-hide   don't show them as extra drives in Nautilus's sidebar
#   x-gvfs-trash  always include their trash in Nautilus's Trash
#   nofail        a missing subvolume never stops the boot
# Safe to re-run (skips lines already there). Run as your user: bash this-file
# Undo: sudo cp /etc/fstab.before-trash-mounts /etc/fstab && sudo systemctl daemon-reload
#       then reboot (or: sudo umount ~/Downloads ~/Videos/Recordings ~/.cache ~/.local/share/Steam)
set -euo pipefail

LOG_DIR="$HOME/.local/state/dotfiles/logs"
if [[ -z ${ROOTSTEP_LOGGING:-} ]]; then
  mkdir -p "$LOG_DIR"
  LOG="$LOG_DIR/$(basename "$0" .sh)-$(date +%Y%m%d-%H%M%S).log"
  export ROOTSTEP_LOGGING="$LOG"
  exec script -q -e -f -c "$(printf '%q ' bash "$0" "$@")" "$LOG"
fi

say() { printf '\n==> %s\n' "$*"; }
[[ $EUID -ne 0 ]] || { echo "run as your normal user (not with sudo)"; exit 1; }

# /home's own line tells us the filesystem and options to reuse
home_src=$(findmnt -no UUID /home)
home_sub=$(findmnt -no FSROOT /home)                 # e.g. /@home
opts=$(findmnt -no OPTIONS /home | sed -E 's/(^|,)(subvolid|subvol)=[^,]*//g; s/^,//')
[[ -n $home_src && $(findmnt -no FSTYPE /home) == btrfs ]] || { echo "stop  /home is not btrfs"; exit 1; }

say "Adding fstab lines (backup: /etc/fstab.before-trash-mounts)"
[[ -e /etc/fstab.before-trash-mounts ]] || sudo cp /etc/fstab /etc/fstab.before-trash-mounts
for d in "$HOME/Downloads" "$HOME/Videos/Recordings" "$HOME/.cache" "$HOME/.local/share/Steam"; do
  if [[ ! -d $d || $(stat -c %i "$d") != 256 ]]; then echo "  skip  $d (not a subvolume)"; continue; fi
  if grep -qsE "^[^#]*[[:space:]]${d}[[:space:]]" /etc/fstab; then echo "  ok    $d (already in fstab)"; continue; fi
  # btrfs's own name for it (first line of `subvolume show`, e.g. @home/<you>/Downloads)
  sub="/$(sudo btrfs subvolume show "$d" | head -1 | sed 's|^/||')"
  [[ $sub == "$home_sub/"* ]] || { echo "stop  unexpected subvolume path '$sub' for $d"; exit 1; }
  printf 'UUID=%s  %s  btrfs  %s,subvol=%s,nofail,x-gvfs-hide,x-gvfs-trash  0 0\n' \
    "$home_src" "$d" "$opts" "$sub" | sudo tee -a /etc/fstab >/dev/null
  echo "  added $d"
done

say "Mounting them now (no reboot needed)"
sudo systemctl daemon-reload
for d in "$HOME/Downloads" "$HOME/Videos/Recordings" "$HOME/.cache" "$HOME/.local/share/Steam"; do
  grep -qsE "^[^#]*[[:space:]]${d}[[:space:]]" /etc/fstab || continue
  if findmnt -n "$d" >/dev/null; then echo "  ok    $d (mounted)"; else sudo mount "$d" && echo "  mounted $d"; fi
done

say "Checking: trash a test file in Downloads"
t="$HOME/Downloads/.trash-test-$$"; echo test > "$t"
if gio trash "$t" 2>/dev/null; then
  echo "  ok    Move to Trash works in Downloads"
  rm -f "$HOME/Downloads/.Trash-$(id -u)/files/.trash-test-$$" "$HOME/Downloads/.Trash-$(id -u)/info/.trash-test-$$.trashinfo"
else
  rm -f "$t"; echo "  check trashing in Downloads still fails"
fi
echo
echo "Done. Close and reopen Nautilus. Log: ${ROOTSTEP_LOGGING/#$HOME/\~} (tell Claude you're done)"

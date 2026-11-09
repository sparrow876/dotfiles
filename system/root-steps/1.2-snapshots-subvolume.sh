#!/usr/bin/env bash
# ROOT-STEPS 1.2: move snapper's /.snapshots into its own top-level subvolume
# `@snapshots`, so rolling back `@` doesn't take the snapshots with it.
#
# Run as your normal user:   bash system/root-steps/1.2-snapshots-subvolume.sh
# It calls sudo for each command (asks for your password once).
# Safe to re-run: every step checks whether it's already done.
#
# Undo: remove the /.snapshots line from /etc/fstab, `sudo umount /.snapshots`,
# then delete @snapshots from the top-level subvolume (see ROOT-STEPS.md 1).
set -euo pipefail

UUID="$(findmnt -no UUID /)"
TOP=/mnt/btrfs-top
FSTAB_LINE="UUID=$UUID  /.snapshots  btrfs  rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@snapshots  0 0"

say() { printf '\n==> %s\n' "$*"; }

[[ -n $UUID ]] || { echo "could not detect root filesystem UUID"; exit 1; }
[[ -f /etc/snapper/configs/root ]] || { echo "run step 1.1 first (snapper -c root create-config /)"; exit 1; }

if findmnt -no SOURCE /.snapshots 2>/dev/null | grep -q '@snapshots'; then
  say "/.snapshots is already mounted from @snapshots. Nothing to do."
  findmnt /.snapshots
  exit 0
fi

say "1/6 Removing the nested /.snapshots subvolume that snapper created"
if sudo test -d /.snapshots && [[ $(stat -c %i /.snapshots) == 256 ]]; then
  if [[ -n $(sudo ls -A /.snapshots) ]]; then
    echo "/.snapshots is not empty (snapshots already taken?). Stopping so nothing is lost."
    sudo ls -la /.snapshots
    exit 1
  fi
  sudo btrfs subvolume delete /.snapshots
else
  echo "already removed"
fi

say "2/6 Creating the empty /.snapshots mount point"
sudo mkdir -p /.snapshots

say "3/6 Creating subvolume @snapshots at the top level of the btrfs disk"
sudo mkdir -p "$TOP"
mountpoint -q "$TOP" || sudo mount -o subvolid=5 "UUID=$UUID" "$TOP"
if sudo test -d "$TOP/@snapshots"; then
  echo "@snapshots already exists"
else
  sudo btrfs subvolume create "$TOP/@snapshots"
fi
sudo umount "$TOP"

say "4/6 Adding the /.snapshots line to /etc/fstab"
if grep -q 'subvol=/@snapshots' /etc/fstab; then
  echo "already in fstab"
else
  sudo cp /etc/fstab /etc/fstab.bak
  echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null
  echo "added (backup at /etc/fstab.bak)"
fi

say "5/6 Mounting it"
sudo systemctl daemon-reload
sudo mount /.snapshots
sudo chmod 750 /.snapshots

say "6/6 Check: the SOURCE column should end in [/@snapshots]"
findmnt /.snapshots

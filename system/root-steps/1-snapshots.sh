#!/usr/bin/env bash
# ROOT-STEPS 1.1-1.4: snapper for / and /home, snapshots in their own @snapshots
# subvolume, snap-pac (automatic snapshots around every pacman run), timers.
#
# Run as your normal user, from the desktop or a TTY:
#   bash ~/dotfiles/system/root-steps/1-snapshots.sh
# It calls sudo itself (asks for your password once). Safe to re-run: every
# step checks whether it's already done. Undo: see ROOT-STEPS.md section 1.
set -euo pipefail

UUID="$(findmnt -no UUID /)"
TOP=/mnt/btrfs-top
FSTAB_LINE="UUID=$UUID  /.snapshots  btrfs  rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@snapshots  0 0"

say() { printf '\n==> %s\n' "$*"; }
[[ $EUID -ne 0 ]] || { echo "run as your normal user (not with sudo)"; exit 1; }
[[ -n $UUID ]] || { echo "could not detect root filesystem UUID"; exit 1; }
sudo -v

# --- 1.1 -------------------------------------------------------------------
say "1.1 Installing snapper and creating the root config"
sudo pacman -S --needed --noconfirm snapper
if [[ -f /etc/snapper/configs/root ]]; then
  echo "root config already exists"
else
  sudo snapper -c root create-config /
fi

# --- 1.2 -------------------------------------------------------------------
say "1.2 Moving /.snapshots to its own top-level subvolume @snapshots"
if findmnt -no SOURCE /.snapshots 2>/dev/null | grep -q '@snapshots'; then
  echo "already done"
else
  if sudo test -d /.snapshots && [[ $(stat -c %i /.snapshots) == 256 ]]; then
    if [[ -n $(sudo ls -A /.snapshots) ]]; then
      echo "/.snapshots is not empty (snapshots already taken?). Stopping so nothing is lost."
      sudo ls -la /.snapshots
      exit 1
    fi
    sudo btrfs subvolume delete /.snapshots
  fi
  sudo mkdir -p /.snapshots "$TOP"
  mountpoint -q "$TOP" || sudo mount -o subvolid=5 "UUID=$UUID" "$TOP"
  sudo test -d "$TOP/@snapshots" || sudo btrfs subvolume create "$TOP/@snapshots"
  sudo umount "$TOP"
  if ! grep -q 'subvol=/@snapshots' /etc/fstab; then
    sudo cp /etc/fstab /etc/fstab.bak
    echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null
    echo "added /.snapshots to /etc/fstab (backup: /etc/fstab.bak)"
  fi
  sudo systemctl daemon-reload
  sudo mount /.snapshots
fi
sudo chmod 750 /.snapshots
findmnt /.snapshots

# --- 1.3 -------------------------------------------------------------------
say "1.3 Root snapshot limits, snap-pac, cleanup timer"
sudo snapper -c root set-config TIMELINE_CREATE=no NUMBER_LIMIT=10 \
  NUMBER_LIMIT_IMPORTANT=5 ALLOW_GROUPS=wheel SYNC_ACL=yes
sudo pacman -S --needed --noconfirm snap-pac
sudo systemctl enable --now snapper-cleanup.timer

# --- 1.4 -------------------------------------------------------------------
say "1.4 Home snapshots on a timer (6 hourly, 7 daily, 2 weekly)"
if [[ -f /etc/snapper/configs/home ]]; then
  echo "home config already exists"
else
  sudo snapper -c home create-config /home
fi
sudo snapper -c home set-config TIMELINE_CREATE=yes TIMELINE_LIMIT_HOURLY=6 \
  TIMELINE_LIMIT_DAILY=7 TIMELINE_LIMIT_WEEKLY=2 TIMELINE_LIMIT_MONTHLY=0 \
  TIMELINE_LIMIT_YEARLY=0 ALLOW_GROUPS=wheel SYNC_ACL=yes
sudo systemctl enable --now snapper-timeline.timer

say "Done. Checks:"
echo "- /.snapshots source (should end in [/@snapshots]):"
findmnt -no SOURCE /.snapshots
echo "- snapper configs:"; snapper list-configs
echo "- timers:"; systemctl list-timers 'snapper-*' --no-pager | head -4
echo
echo "Next: step 1.5 from a TTY with the desktop logged out:"
echo "  bash ~/dotfiles/system/root-steps/1.5-home-subvolumes.sh"

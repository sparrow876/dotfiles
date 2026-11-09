# Root steps (you run these by hand)

Every action that needs `sudo`, touches `/etc`, enables a system service or changes
your login shell is listed here, **in order**, with what it does and how to undo it.
Claude never runs these. Copy one block at a time into a terminal and read the output.

Conventions:
- `~/dotfiles` is this repo. Commands assume you start in it: `cd ~/dotfiles`.
- **Undo** lines reverse the block directly above them.
- Sections marked *(later)* belong to a later build step. Skip them until that step.

**Scripts:** the same commands as scripts in `system/root-steps/`, one per stretch
between reboots. Each calls `sudo` itself, skips what's already done, and is safe
to re-run. 2-nvidia.sh and 3-system.sh save their full output to
`~/.local/state/dotfiles/logs/`, so you can tell Claude "done" instead of pasting.
The sections below explain what each command does and how to undo it.

| Run | Covers | When |
|-----|--------|------|
| `bash system/root-steps/1-snapshots.sh` | 1.1–1.4 | any time |
| `bash system/root-steps/1.5-home-subvolumes.sh` | 1.5 | from a TTY, desktop logged out (no sudo) |
| `bash system/root-steps/2-nvidia.sh` | 2.1–2.2 | then **reboot** |
| `bash system/root-steps/3-system.sh` | 2.3 checks, 3, 4, 5, 6, 7 | after that reboot, inside the desktop |

System facts these steps rely on (checked 2026-11-09): Arch, kernel `linux` 7.2,
**btrfs** root (`@`, `@home`, `@pkg`, `@log`, mounted with `subvol=` in fstab and the
kernel cmdline), **systemd-boot** booting a UKI (`/boot/EFI/Linux/arch-linux.efi`),
`kms` in mkinitcpio HOOKS, `nouveau` currently loaded, multilib disabled,
`power-profiles-daemon` installed, AUR helper `yay`.

---

## 1. Snapshots (do this first)

Tools: **snapper** (manages btrfs snapshots) + **snap-pac** (takes a "pre" and "post"
snapshot of `/` around every pacman transaction, automatically).
Since you're keeping systemd-boot, there is no boot-menu entry for snapshots. Rolling
back is done from a TTY or a live USB (1.6).

### 1.1 Install snapper, create the root config

```sh
sudo pacman -S --needed snapper
sudo snapper -c root create-config /
```
Creates `/etc/snapper/configs/root` and a `/.snapshots` subvolume nested inside `@`.

### 1.2 Move snapshots to their own top-level subvolume `@snapshots`

A rollback replaces `@`. If the snapshots lived inside `@` they'd be swapped out with
it, so they get their own subvolume next to `@` (standard Arch wiki layout).

```sh
sudo btrfs subvolume delete /.snapshots          # the nested one snapper just made (empty)
sudo mkdir /.snapshots
sudo mount --mkdir -o subvolid=5 UUID=$(findmnt -no UUID /) /mnt/btrfs-top
sudo btrfs subvolume create /mnt/btrfs-top/@snapshots
sudo umount /mnt/btrfs-top
echo "UUID=$(findmnt -no UUID /)  /.snapshots  btrfs  rw,relatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@snapshots  0 0" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount /.snapshots
sudo chmod 750 /.snapshots
findmnt /.snapshots                                # should show [/@snapshots]
```

### 1.3 Snapshot limits and access

```sh
# No hourly snapshots of / (pacman snapshots are enough); keep the last 10 pairs.
sudo snapper -c root set-config TIMELINE_CREATE=no NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 ALLOW_GROUPS=wheel SYNC_ACL=yes
sudo pacman -S --needed snap-pac               # from now on every pacman run is snapshotted
sudo systemctl enable --now snapper-cleanup.timer
snapper -c root list                           # works without sudo thanks to ALLOW_GROUPS
```

### 1.4 Home snapshots (hourly/daily safety net for your files)

```sh
sudo snapper -c home create-config /home
sudo snapper -c home set-config TIMELINE_CREATE=yes TIMELINE_LIMIT_HOURLY=6 TIMELINE_LIMIT_DAILY=7 TIMELINE_LIMIT_WEEKLY=2 TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 ALLOW_GROUPS=wheel SYNC_ACL=yes
sudo systemctl enable --now snapper-timeline.timer
```
snap-pac only snapshots the `root` config, so `/home` is snapshotted on the timer only.

### 1.5 Keep big and throwaway folders out of snapshots (no sudo needed)

btrfs snapshots skip nested subvolumes, so each excluded folder becomes its own
subvolume. **Do this from a TTY (Ctrl+Alt+F3) before logging into the desktop**, so
nothing is writing to `~/.cache`. Existing contents are copied over.

```sh
mksubvol() {
  d="$1"
  [ -d "$d" ] && [ "$(stat -c %i "$d")" = 256 ] && { echo "$d already a subvolume"; return; }   # inode 256 = subvolume root
  [ -e "$d" ] && mv "$d" "$d.old"
  mkdir -p "$(dirname "$d")"
  btrfs subvolume create "$d"
  if [ -d "$d.old" ]; then cp -a --reflink=always "$d.old/." "$d/" && rm -rf "$d.old"; fi
}
mksubvol ~/.cache                  # also holds the rclone (Google Drive) cache + thumbnails
mksubvol ~/Downloads
mksubvol ~/Videos/Recordings
mksubvol ~/.local/share/Steam      # Steam + its default game library; do this BEFORE installing Steam
```
The Google Drive mount (`~/GoogleDrive`) is a FUSE mount; btrfs never snapshots other
mounts, so it needs nothing. If you later add a second Steam library folder, run
`mksubvol` on it before adding it in Steam.

Undo (per folder, keeps the files): `mv ~/X ~/X.sub && mkdir ~/X && cp -a --reflink=always ~/X.sub/. ~/X/ && sudo btrfs subvolume delete ~/X.sub`

### 1.6 How to roll back (plain English)

Before every package update snap-pac saves a "pre" snapshot of `/`. If an update
breaks the system, you swap the broken root subvolume `@` for a copy of that "pre"
snapshot and reboot. Your home folder isn't touched. Only `/boot` (the EFI partition,
which holds the kernel image) isn't part of the snapshot, so if the bad update
included a new kernel, you reinstall the old kernel once after rolling back.
Find the snapshot number with `snapper -c root list` (look for the `pre` entry whose
description is the bad pacman command; times are local). Then, from a TTY or an Arch
live USB:

```sh
N=123                                                     # the "pre" snapshot number
sudo mount --mkdir -o subvolid=5 /dev/nvme0n1p2 /mnt/btrfs-top
sudo mv /mnt/btrfs-top/@ /mnt/btrfs-top/@broken
sudo btrfs subvolume snapshot /mnt/btrfs-top/@snapshots/$N/snapshot /mnt/btrfs-top/@
sudo umount /mnt/btrfs-top && reboot
# After reboot, ONLY if that update changed the `linux` package
# (check: grep -E 'upgraded linux ' /var/log/pacman.log | tail -3):
sudo pacman -S linux && reboot     # reinstalls the snapshot's kernel version + rebuilds the UKI
# Once everything works again, delete the broken copy:
sudo mount --mkdir -o subvolid=5 /dev/nvme0n1p2 /mnt/btrfs-top && sudo btrfs subvolume delete /mnt/btrfs-top/@broken
```
On a live USB, drop `sudo`. Restoring single files from home:
`snapper -c home list`, then copy from `/home/.snapshots/<N>/snapshot/<user>/...`.

**Undo all of section 1:** `sudo systemctl disable --now snapper-timeline.timer snapper-cleanup.timer`,
`sudo pacman -Rns snap-pac snapper`, remove the `/.snapshots` line from `/etc/fstab`,
then delete `@snapshots` and `/home/.snapshots` with `btrfs subvolume delete`.

---

## 2. NVIDIA driver (RTX 3050, used via `prime-run`; Hyprland stays on the Intel iGPU)

### 2.1 Install the driver

```sh
sudo pacman -S --needed nvidia-open nvidia-utils egl-wayland libva-nvidia-driver nvidia-prime mesa-utils vulkan-tools
```
- `nvidia-open` = prebuilt open kernel modules for the `linux` kernel (the current
  Arch package for Turing and newer; Ampere = RTX 30xx). If you ever add another
  kernel (e.g. linux-zen), switch to `nvidia-open-dkms` + its headers.
- `nvidia-utils` ships `/usr/lib/modprobe.d/nvidia-utils.conf`, which already
  **blacklists nouveau** and sets `NVreg_TemporaryFilePath=/var/tmp`.

Undo: `sudo pacman -Rns nvidia-open nvidia-utils egl-wayland libva-nvidia-driver nvidia-prime`

### 2.2 Keep nouveau out of the initramfs

The `kms` hook copies `nouveau` into early boot, before the blacklist applies.
Arch's NVIDIA wiki page says to remove it:

```sh
sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
sudo sed -i 's/^\(HOOKS=(.*\) kms\(.*\)$/\1\2/' /etc/mkinitcpio.conf
grep ^HOOKS /etc/mkinitcpio.conf                 # 'kms' should be gone
sudo mkinitcpio -P                               # rebuilds the UKI
```
The Intel iGPU still gets KMS a second later from the normal module load. You may see
one extra flicker at boot.

Undo: `sudo mv /etc/mkinitcpio.conf.bak /etc/mkinitcpio.conf && sudo mkinitcpio -P`

### 2.3 Reboot and check

```sh
reboot
lsmod | grep -E '^(nvidia|nouveau)'              # nvidia*, no nouveau
cat /sys/module/nvidia_drm/parameters/modeset    # Y  (on by default since driver 560)
cat /sys/module/nvidia_drm/parameters/fbdev      # Y  (on by default since 570)
grep PreserveVideoMemoryAllocations /proc/driver/nvidia/params   # should be 1
cat /proc/driver/nvidia/gpus/*/power             # "Runtime D3 status: Enabled (fine-grained)" = dGPU sleeps when idle
nvidia-smi                                       # shows the RTX 3050
prime-run glxinfo -B | grep -i 'renderer'        # NVIDIA GeForce RTX 3050 ...
glxinfo -B | grep -i 'renderer'                  # Intel (the default stays the iGPU)
```
Only if `modeset` or `fbdev` says `N`: add `nvidia_drm.modeset=1 nvidia_drm.fbdev=1`
to `/etc/kernel/cmdline` and run `sudo mkinitcpio -P`.

### 2.4 Suspend / resume

**Different from the original brief, on purpose:** with driver 595+ and the open
kernel modules, video memory is saved by the kernel's suspend hooks, so the
`nvidia-suspend/hibernate/resume` services are **no longer needed**. The current
`nvidia-utils` package disables them itself on upgrade (see its install script).
Don't enable them.
Check: `PreserveVideoMemoryAllocations` reads `1` above. Suspend gets tested in step 14.

Only if it reads `0`:
```sh
echo 'options nvidia NVreg_PreserveVideoMemoryAllocations=1' | sudo tee /etc/modprobe.d/nvidia-power.conf
sudo mkinitcpio -P && reboot
```
Undo: `sudo rm /etc/modprobe.d/nvidia-power.conf && sudo mkinitcpio -P`

---

## 3. Full-tilt performance profile

`power-profiles-daemon` is installed and would restore whatever profile it last saw.
Since you want performance always and no profile switching, mask it and pin the HP
firmware profile with a small unit (boot, resume and charger plug/unplug).

```sh
sudo systemctl mask --now power-profiles-daemon.service
sudo install -Dm644 system/units/platform-profile-performance.service /etc/systemd/system/platform-profile-performance.service
sudo install -Dm644 system/units/99-platform-profile.rules /etc/udev/rules.d/99-platform-profile.rules
sudo systemctl daemon-reload && sudo udevadm control --reload
sudo systemctl enable --now platform-profile-performance.service
cat /sys/firmware/acpi/platform_profile          # performance
```
Undo: `sudo systemctl disable platform-profile-performance.service && sudo rm /etc/systemd/system/platform-profile-performance.service /etc/udev/rules.d/99-platform-profile.rules && sudo systemctl unmask power-profiles-daemon.service`

---

## 4. Enable multilib (32-bit libraries for Steam/Proton)

```sh
sudo cp /etc/pacman.conf /etc/pacman.conf.bak
sudo sed -i '/^#\[multilib\]$/{s/^#//;n;s/^#//}' /etc/pacman.conf
grep -A1 '^\[multilib\]' /etc/pacman.conf        # both lines uncommented
sudo pacman -Syu
```
Undo: `sudo mv /etc/pacman.conf.bak /etc/pacman.conf && sudo pacman -Syu`
(and remove `steam` + `lib32-*` packages first).

---

## 5. Install all packages

```sh
./install.sh --packages
```
Runs `sudo pacman -S --needed` on `packages/pacman.txt`, then `yay -S --needed` on the
uncommented lines of `packages/aur.txt`. Each AUR package's PKGBUILD summary is in
that file. yay will show you the PKGBUILD diff; read it.
**This machine has `pulseaudio` and `jack2` installed.** pacman will say they conflict
with `pipewire-pulse` / `pipewire-jack` and ask to remove them: answer **y**. The
default (N) cancels the whole install.
Then the user-level part (no sudo): `./install.sh`.
Undo: remove what you don't want with `sudo pacman -Rns <pkg>`.

---

## 6. System services and maintenance timers

```sh
# Already running on this machine (listed for a fresh install):
sudo systemctl enable --now NetworkManager.service bluetooth.service

# Pacman cache: weekly cleanup, keep the last 2 versions
sudo install -Dm644 system/units/paccache.service.d/keep-2.conf /etc/systemd/system/paccache.service.d/keep-2.conf
sudo systemctl daemon-reload
sudo systemctl enable --now paccache.timer

# Mirrors: weekly refresh, HTTPS, India + nearby, fastest of the latest 20
sudo cp /etc/xdg/reflector/reflector.conf /etc/xdg/reflector/reflector.conf.bak
sudo install -Dm644 system/etc/reflector.conf /etc/xdg/reflector/reflector.conf
sudo systemctl enable --now reflector.timer
sudo systemctl start reflector.service           # run once now (~30s), then check:
head -15 /etc/pacman.d/mirrorlist
```
Undo: `sudo systemctl disable --now paccache.timer reflector.timer`,
`sudo rm -r /etc/systemd/system/paccache.service.d`,
`sudo mv /etc/xdg/reflector/reflector.conf.bak /etc/xdg/reflector/reflector.conf`.

Firmware updates (no service needed, run occasionally):
```sh
fwupdmgr refresh
fwupdmgr get-updates          # lists available updates; `fwupdmgr update` applies them
```
HP doesn't always publish laptop BIOS updates to LVFS. If nothing shows up, check HP's
support page for your model (their Windows-based updater or a BIOS USB flash).

`pacdiff` (from pacman-contrib) merges `.pacnew` config files after updates:
`sudo DIFFPROG='nvim -d' pacdiff`. `scripts/update.sh` (step 20) lists them for you.

---

## 7. Firewall (ufw)

Default: block everything incoming, allow everything outgoing. Two exceptions, both
**only from your local subnet**: LocalSend (phone sharing) and, in step 19, ACC LAN.

```sh
SUBNET=$(ip -4 route | awk '/proto kernel/ && /dev wl/ {print $1; exit}')
echo "$SUBNET"                                   # e.g. 10.139.165.0/24; stop if empty
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw logging low                             # blocked packets -> journalctl -k | grep UFW
sudo ufw allow from "$SUBNET" to any port 53317 proto tcp comment 'LocalSend'
sudo ufw allow from "$SUBNET" to any port 53317 proto udp comment 'LocalSend'
sudo ufw enable
sudo systemctl enable ufw.service
sudo ufw status verbose
```
The subnet is whatever network you're on now. On another network (e.g. home Wi-Fi),
run the same `SUBNET=` + two `allow` lines there; rules for each subnet stay in place.

**ACC LAN rules (later, step 19):** the exact ports come from your server machine's
`cfg/configuration.json` (`udpPort`, `tcpPort`) plus ACC's LAN discovery port.
I'll verify them and add the exact commands here.

**ProtonVPN check (after ProtonVPN is installed):** connect the VPN, open a website
(should work); disconnect, and check the kill switch does what you set in the
ProtonVPN app (blocks traffic while disconnected if enabled, otherwise normal
internet). `sudo ufw status` should look the same before and after. ProtonVPN
manages its own kill switch through NetworkManager, not ufw.

Undo: `sudo ufw disable && sudo systemctl disable ufw.service` (`sudo ufw reset` wipes the rules).

---

## 8. Login shell → zsh *(later, step 3)*

```sh
chsh -s /usr/bin/zsh          # asks for your password; takes effect at next login
```
Undo: `chsh -s /usr/bin/bash`

---

## 9. *(later)* Placeholders filled in by later steps

- **Step 14:** run qylock's `sddm.sh` / `quickshell.sh` (summarized first), enable
  `sddm.service`, set the theme, Hyprland session entry, `pam_gnome_keyring` for SDDM.
- **Step 16:** `systemctl --user enable --now rclone-gdrive.service` (no sudo).
- **Step 19:** ACC LAN firewall rules, controller udev rules if needed.

# Apps: install notes, sign-in, limitations

Work and chat apps (Outlook, Teams, Discord, Claude) are added in build step 17.

## Google Drive (rclone)

GNOME's own Google Drive support (Online Accounts + gvfs) was removed in GNOME 50,
so Drive is mounted with **rclone** at `~/GoogleDrive` and shows up in Nautilus's
sidebar as **Google Drive**.

**One-time sign-in** (you, no sudo):
```sh
rclone config
#  n  (new remote)  ->  name: gdrive  ->  storage: drive (Google Drive)
#  client_id / client_secret: leave empty  ->  scope: 1 (full access)
#  service_account_file: empty  ->  advanced config: n  ->  auto config: y
#  (a browser opens: sign in, allow)  ->  shared drive: n  ->  y (keep)  ->  q
systemctl --user enable --now rclone-gdrive.service
```
Your token is stored in `~/.config/rclone/rclone.conf`. It is **never** in this
repo (`.gitignore` blocks `rclone.conf` and any `rclone/` folder).

**How it behaves**
- Google Docs / Sheets / Slides appear as exported files (`.docx`, `.xlsx`,
  `.pptx`). Editing them locally uploads a *new* Office file next to the original;
  edit real Google Docs in the browser.
- The first time you open a big file it's downloaded (slower); after that it's
  served from the cache in `~/.cache/rclone` (max 10 GB, files unused for 72 h are
  dropped). Saving writes to the cache first and uploads in the background.
- Changes made elsewhere (phone, web) show up within about a minute.
- Without internet the mount is still there but only cached files open.

**Check it**
```sh
systemctl --user status rclone-gdrive     # running? errors?
journalctl --user -u rclone-gdrive -n 50  # recent log
ls ~/GoogleDrive                          # your Drive's top level
findmnt ~/GoogleDrive                     # shows fuse.rclone when mounted
```
If it says the token expired: `rclone config reconnect gdrive:` then
`systemctl --user restart rclone-gdrive`.

Snapshots never include it (FUSE mount; the cache is inside the `~/.cache`
subvolume), and the stats panel skips it.

## LocalSend (phone ↔ laptop)

AirDrop-style sharing over Wi-Fi. Open **LocalSend** from the launcher (not
autostarted). Phone and laptop must be on the same network; the firewall allows
port 53317 (TCP + UDP) **only from the local subnet** you added in ROOT-STEPS §7.
On a different network (e.g. home Wi-Fi), add that subnet the same way.
The window floats centered (Hyprland rule).

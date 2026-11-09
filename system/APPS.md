# Apps: install notes, sign-in, limitations

Install the chat apps (AUR, PKGBUILDs reviewed; notes in `packages/aur.txt`):
```sh
yay -S --needed teams-for-linux-bin vesktop-bin claude-desktop
```
None of them autostart. All of them: native Wayland (sharp text), tray icon,
notifications through the bar's notification server, screen sharing through
the Wayland portal (xdg-desktop-portal-hyprland: you pick a screen or window in
the share dialog), mic + camera through PipeWire.
Clicking one of their notifications brings the app forward; they can't steal
focus or switch your workspace by themselves.

## Microsoft Outlook (web app)

No Linux app exists, so **Outlook** in the launcher is Outlook on the web in its
own Chromium window (own profile in `~/.local/share/webapps/outlook`, separate
from Zen). Sign in once; it stays signed in.
- Dark mode: Outlook → Settings → General → Appearance → Dark (Chromium also
  asks sites for dark mode).
- Notifications: allow them when Outlook asks (or the padlock → Notifications).
- Window class `chrome-outlook.office.com__mail_-Default` (Hyprland rules).

## Microsoft Teams (teams-for-linux)

Microsoft retired its Linux client; **teams-for-linux** is an unofficial
wrapper around Teams on the web.
- Sign in with your work/school account. Some organizations block unmanaged
  devices or "unsupported clients"; if sign-in is refused, use Teams on the web
  in a Chromium app window instead:
  `chromium --user-data-dir="$HOME/.local/share/webapps/teams" --app=https://teams.microsoft.com`
- Closing the window keeps it in the tray (it keeps notifying); quit from the
  tray icon.
- Screen sharing: Share → pick a screen/window in the portal dialog.
- Settings file: `~/.config/teams-for-linux/config.json` (app-owned, not in
  this repo).
- `msteams:` links open it.

## Discord (Vesktop)

**Vesktop** is a third-party Discord client (Vencord built in) with better
Wayland screen sharing **including audio**. Discord's terms technically don't
allow third-party clients (you chose it knowing that).
- Palette theme: Settings → Vencord → **Themes** → enable **rice** (once). It
  follows ALT + T theme switches (the file is regenerated).
- Closing the window minimizes to the tray (Settings → Vesktop → "Minimize to
  tray" if you want to change it).
- Screen share with audio: in the share dialog pick the window/screen and the
  audio source.
- `discord:` links open it.

## Claude (desktop)

`claude-desktop` repackages **Anthropic's official .deb** (downloaded from
downloads.claude.ai, checksum-pinned). It also installs QEMU + OVMF (a few
hundred MB) for the app's "Cowork" feature, which runs tasks in a small VM.
- Extra launch flags: `~/.config/claude-desktop-flags.conf`.
- Sign-in data stays in `~/.config/Claude` (app-owned, never in this repo).

## Testing checklist (step 17)

1. Launch each from ALT + D: correct icon in the launcher, sharp text.
2. Tray icon appears (Teams, Vesktop, Claude); right-click opens the themed menu.
3. Send yourself a message: the notification shows top-right; clicking it
   focuses the app (even from another workspace).
4. Calls (Teams + Vesktop): mic, camera, screen share (a window and the whole
   screen; Vesktop with audio). If a call opens a small pop-out window, tell
   Claude its title so the "call-popouts" rule (float, pin, bottom-right) can
   match it exactly.

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

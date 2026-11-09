# MAINTENANCE

Read this first in every session (CLAUDE.md, section 0). It explains how the
system is built, the traps already hit, and a dated log of fixes. Keep it
current: add a log entry after every fix and update the reference parts
whenever the structure changes.

Contents:
1. [Snapshot](#1-snapshot)
2. [How the system is built](#2-how-the-system-is-built)
3. [Adding, changing or removing a component](#3-adding-changing-or-removing-a-component)
4. [Gotchas](#4-gotchas)
5. [Decisions that differ from the brief](#5-decisions-that-differ-from-the-brief)
6. [Known limitations / open items](#6-known-limitations--open-items)
7. [How to verify changes](#7-how-to-verify-changes)
8. [Recovery](#8-recovery)
9. [Log](#9-log)

---

## 1. Snapshot

Recorded 2026-11-09 (build steps 1–15 done).

| Component | Version |
|-----------|---------|
| Kernel | linux 7.2.14-arch1-1 |
| Hyprland | 0.57.1 (Lua config) |
| Quickshell | 0.3.2 |
| NVIDIA | nvidia-open / nvidia-utils 615.78.08 |
| Mesa | 26.2.6 |
| PipeWire / WirePlumber | 1.6.10 / 0.5.18 |
| awww (ex-swww) | 0.12.1 |
| hypridle | 0.1.8 |
| rofi | 2.0.0 (native Wayland) |
| kitty | 0.49.2 |
| gpu-screen-recorder | 6.1.7 |
| SDDM | 0.21.0 (X11 greeter) |

Hardware: HP Victus 15 (fa0xxx), i5-12450H, Intel Alder Lake iGPU (`i915`,
drives eDP-1, `boot_vga=1`) + RTX 3050 Laptop (GA107, drives HDMI, sleeps in
runtime D3 when unused). eDP-1 1920x1080@144, no VRR. Battery `BAT0`, charger
`ADP1`, backlight `intel_backlight`, no keyboard backlight. Sound: SOF
`skl_hda_dsp_generic` (Speaker, 3×HDMI, 2 mics). Wi-Fi `wlp4s0`, Ethernet `eno1`.
Root on btrfs (`@`, `@home`, `@pkg`, `@log`, `@snapshots`), systemd-boot + UKI.
AUR helper: **yay** (not paru).

---

## 2. How the system is built

### 2.1 Layers (bottom to top)

1. **Packages**: `packages/pacman.txt`, `packages/aur.txt` (AUR entries are only
   uncommented after their PKGBUILD was read; notes inline).
2. **Root steps**: `system/ROOT-STEPS.md` (every sudo/`/etc` action, with undo)
   and `system/root-steps/*.sh` (the same as scripts, one per stretch between
   reboots; they log to `~/.local/state/dotfiles/logs/`, so read the newest log
   instead of asking for pasted output). Claude never runs these.
3. **`install.sh`** (user level): dirs, default wallpaper, pinned clones
   (Oh My Zsh + 2 plugins, qylock), `theme/render.sh`, GNU Stow, gsettings.
   `./install.sh --packages` installs packages (user runs it).
4. **Stow packages**: top-level dirs mirroring `$HOME`. Only the ones listed in
   `STOW_PACKAGES` in `install.sh` are linked (a half-built package never
   replaces a working config). `NO_FOLD_DIRS` keeps dirs like `~/.config/gtk-3.0`
   real so app-written files (bookmarks) never land in the repo.
5. **Generated theme files**: `theme/render.sh` fills `theme/templates/**.tmpl`
   from `theme/style.toml` + `theme/palettes/$(cat theme/current).toml`.
   Generated files ARE committed (fresh clone works without rendering).
6. **Runtime**: Hyprland (Lua) autostarts polkit agent, hypridle, awww +
   restore, Quickshell (`qs`), cliphist watchers, wl-clip-persist.

### 2.2 Directory map

| Path | Role |
|------|------|
| `hypr/.config/hypr/hyprland.lua` | only `require("conf.x")` lines |
| `hypr/.config/hypr/conf/` | `env` `monitors` `input` `look` `animations` `rules` `games` `keybinds` `autostart` (Lua) + `colors.lua` (generated) |
| `hypr/.config/hypr/hypridle.conf` | idle chain (hyprlang format, not Lua) |
| `quickshell/.config/quickshell/shell.qml` | entry: one `Variants` per screen for Bar, OSD, StatsPanel, PowerMenu, WallpaperReel, IdleScreen, NotificationPopups; `popups` IPC |
| `quickshell/…/Theme.qml` | generated singleton: colors, fonts, sizes |
| `quickshell/…/services/` | singletons: Audio, Bluetooth, Brightness, IdleInhibit, Keybinds, Media, Network, Notifications, Popups, Recorder, SystemStats (+`sysstats.sh`), Wallpapers |
| `quickshell/…/bar/` | Bar + modules (`*Icon.qml`, Workspaces, MediaModule, Battery, Clock, Tray, TrayMenu, Bell) |
| `quickshell/…/popups/` | `PopupFrame` (shared) + Network/Bluetooth/Audio menus, Calendar |
| `quickshell/…/notifications/` | popups + center |
| `quickshell/…/components/` | StyledText, Icon, Glyphs (all glyphs), Tooltip, Toggle, Slider, IconButton, TextButton, Card, Spinner, Separator, LevelBar, Graph, RingGauge |
| `quickshell/…/{osd,panel,powermenu,wallpaper,idle,cheatsheet}/` | one overlay each |
| `scripts/` | shell helpers (screenshot, ocr, colorpick, clipboard, emoji, lock, logout, idle-dim, wallpaper, record, notify-file, theme-picker, theme-colors.sh (generated)) |
| `theme/` | palettes, style, templates, `render.sh`, `apply.sh`, README |
| `system/` | ROOT-STEPS.md, root-steps scripts, units (platform profile, paccache), etc (reflector.conf) |
| `systemd/.config/environment.d/` | env for D-Bus/systemd-started apps (`GSK_RENDERER`) |
| `zsh/`, `kitty/`, `starship/`, `fastfetch/`, `lazygit/`, `bat/`, `rofi/`, `gtk/` | app configs (stowed) |

### 2.3 Quickshell IPC targets (`qs ipc call <target> <fn>`)

| Target | Functions | Used by |
|--------|-----------|---------|
| `popups` | `toggle <network\|bluetooth\|audio\|calendar\|notifications\|recording>`, `close` | ALT+N |
| `panel` | `toggle` | ALT+S |
| `powermenu` | `toggle` | ALT+Escape |
| `wallpaper` | `toggle` | ALT+W |
| `wallpapers` | `refresh`, `list` | debugging |
| `idle` | `toggle`, `status` | ALT+I (coffee cup) |
| `idlescreen` | `enter`, `leave` | hypridle via `scripts/idle-dim.sh` |
| `cheatsheet` | `toggle` | ALT+/ |
| `notifications` | `dnd`, `clear`, `status` | — |
| `recorder` | `toggleFull`, `toggleRegion`, `replay`, `toggleReplay`, `toggleMic`, `status` | ALT+R, ALT+Shift+R, ALT+Ctrl+R, ALT+Ctrl+Shift+R |
| `audio` | `devices` | debugging |

### 2.4 Keybinds

All in `hypr/.config/hypr/conf/keybinds.lua`, each with a
`description = "Category: Action"` (this replaces the brief's `bindd`; visible
in `hyprctl binds -j`). `scripts/keybinds.jq` turns that JSON into grouped,
readable rows (merges alternatives, collapses `1…6`); it feeds BOTH the cheat
sheet (ALT+/, `services/Keybinds.qml`) and `scripts/keybinds-to-md.sh README.md`
(table between `<!-- keybinds:start/end -->`). New binds appear in both
automatically; only `prettykey` in keybinds.jq may need a new key name. Modifier ALT; SUPER only for
SUPER+L (lock). Scripts are called as `os.getenv("HOME") .. "/dotfiles/scripts/…"`,
so **the repo must live at `~/dotfiles`**.

### 2.5 Event-driven by design (idle CPU ≈ 0)

Nothing polls while idle. Network/Bluetooth/PipeWire/UPower/MPRIS/Hyprland via
Quickshell services (D-Bus/sockets); brightness via one `udevadm monitor`;
stats only while the panel is open; clock at minute precision; gpu-screen-recorder
only while recording/replay is on. Measure Quickshell CPU after any change (§7).

### 2.6 Idle chain

`hypridle.conf`: 240 s `idle-dim.sh dim` (30 % of current brightness + IdleScreen)
→ 300 s `loginctl lock-session` → `lock_cmd` = `scripts/lock.sh` (qylock winter,
never twice) → 360 s DPMS off → 1200 s suspend only if `/sys/class/power_supply/ADP1/online` is 0.
Inhibited by: coffee cup (IdleInhibitor on the bar surface), fullscreen
(`idle_inhibit = "fullscreen"` window rule), D-Bus/systemd inhibitors (calls).

---

## 3. Adding, changing or removing a component

General rule: change the repo, verify (§7), commit with a clear message, add a
log entry (§9), update README/cheat sheets/ROOT-STEPS if they describe it.
**Never remove a feature without asking the user** (CLAUDE.md §30).

- **New bar module**: create `bar/FooIcon.qml` (use `BarIcon` for glyph + click →
  popup), add it to the `RowLayout` in `bar/Bar.qml` with a `Separator`. Name
  bar files `*Icon.qml` if a service has the same base name (§4.2).
- **Remove a bar module**: delete its line + separator in `Bar.qml`, delete the
  file; if its service is now unused, delete the service (unused singletons
  are never instantiated, but keep the tree clean). Remove keybinds/IPC docs.
- **New popup**: `PopupFrame { name: "x"; barWindow; anchorItem }` inside the
  bar icon; open with `Popups.toggle("x", screenName)`. Keyboard-opened popups
  must go through `qs ipc call popups toggle x` (no-grab path, §4.2).
- **New overlay/window**: own folder, `PanelWindow` with
  `WlrLayershell.namespace: "quickshell-<name>"` (prefix required for the blur
  + no-anim layer rule), add a `Variants` in `shell.qml`, an `IpcHandler`,
  and a keybind.
- **New keybind**: `bind(keys, dispatcher, "Category: Action", opts)` in
  `keybinds.lua`; run `Hyprland --verify-config`; regenerate the README table
  (`scripts/keybinds-to-md.sh README.md`). Unusual key names: add to `prettykey`.
- **New window rule**: `hl.window_rule({ name, match = {…}, effect = … })` in
  `rules.lua`; effect names from §4.1.
- **New stow package**: create `<pkg>/<path under $HOME>`, add `<pkg>` to
  `STOW_PACKAGES`, `./install.sh --only stow`. If apps write into that dir,
  add it to `NO_FOLD_DIRS`.
- **New app color file**: add `theme/templates/<repo path>.tmpl` using
  `{{role}}`, `{{role.hex}}`, `{{role.rgb}}`, `{{glass_alpha.alpha}}`… then
  `theme/render.sh`. Never hardcode palette colors anywhere else.
- **New theme**: `theme/palettes/<name>.toml` with the same roles (see
  `theme/README.md`), `theme/apply.sh <name>`, screenshot-check bar, kitty, rofi.
- **New package**: verify name (`pacman -Si` / `yay -Si`), add to the right
  group in `packages/*.txt`; AUR: read the PKGBUILD first and note it inline.
- **New root action**: document in ROOT-STEPS (command, what it does, undo);
  for long blocks, a script in `system/root-steps/` with the logging wrapper.
- **Text sizes**: `theme/style.toml` (`font_px`, `font_px_small`, `font_pt`), GTK
  via `install.sh` gsettings, kitty in `kitty.conf`, Nautilus in `gtk-4.0/gtk.css`.
- **Idle timings**: `hypr/.config/hypr/hypridle.conf` (then restart hypridle).

---

## 4. Gotchas

### 4.1 Hyprland 0.57 (Lua config)

- Config is `hyprland.lua` (`hl.*` API), not `hyprland.conf`. `require` resolves
  relative to the main config's folder.
- Source of truth for syntax: `/usr/share/hypr/stubs/hl.meta.lua` + the source at
  the installed tag (`src/config/lua/bindings/*.cpp`,
  `src/desktop/rule/windowRule/WindowRuleEffectContainer.cpp`). Wiki pages are
  huge; fetched summaries were lossy.
- `Hyprland --verify-config -c <file>` catches unknown keys, rule fields, enum
  values, curve names, animation styles; NOT regexes or size/move expressions.
- `hyprctl dispatch` takes Lua: `hyprctl dispatch 'hl.dsp.exit()'`,
  `'hl.dsp.dpms({action = "off"})'`, `'hl.dsp.focus({ workspace = 6 })'`,
  `'hl.dsp.exec_cmd("qs")'`. `hyprctl configerrors` after `hyprctl reload`.
- Dispatcher args (from source): `focus({direction|workspace})`,
  `window.move({direction|workspace, follow})`, `window.cycle_next({next=false})`
  = previous, `window.fullscreen({mode, action})`.
- Window-rule `move`/`size` expressions are monitor-relative; size is applied
  before move (`monitor_w-window_w-24` works).
- Dialogs with a parent are already centered on the parent; `center = true`
  centers on the monitor instead.
- Aquamarine puts the `boot_vga=1` GPU first and prefers the GPU driving the
  internal panel, so no `AQ_DRM_DEVICES` is needed (iGPU primary).
- Animations: `speed` is deciseconds. A looping `borderangle` animation
  redraws forever; use `once`.
- `hypridle.conf` is still hyprlang format.

### 4.2 Quickshell 0.3.2

- API source of truth: `/usr/lib/qt6/qml/Quickshell/**/*.qmltypes` (+ `qmldir`
  for QML-file types like IconImage).
- `import qs.<folder>` works; root singletons via `import qs`.
- **Name clash**: a bar file and a service singleton with the same name →
  "X is not a type". Bar files use the `*Icon` suffix.
- **Restart**: `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`. Never
  `qs kill` (stops one instance only → duplicates stack up). Hot reload keeps
  old child processes and stale layer sizes; restart for visual/CPU checks.
  A restart also clears notification history and stops replay mode.
- **Grabbing popups** (`grabFocus: true`) fail ("Failed to create grabbing
  popup") unless the bar just received input → keybind/IPC-opened popups use
  `Popups.toggle(name, screen, false)` = no grab + `HyprlandFocusGrab`.
- `qs ipc call <target> show` is hijacked by the CLI (`qs ipc show`): never
  name an IPC function `show`.
- Any 60 fps animation in the bar costs 15–30 % CPU (whole bar re-renders;
  ~7 % floor even for a tiny surface). `FrameAnimation` keeps the render loop
  at 144 Hz. Canvas 2D is CPU-heavy. Keep bar animations short/event-driven;
  slow ambient motion: a 100 ms `Timer` (IdleScreen ≈ 2 %).
- `Repeater` over a JS array recreates every delegate on change (restarts
  timers/animations) → use `ScriptModel { values: … }`.
- PipeWire node properties (names, `media.class`) exist only for tracked
  nodes: filter by `n.type === PwNodeType.AudioSink/AudioSource/AudioOutStream`
  and track with `PwObjectTracker`.
- UPower `percentage` is 0..1. Hyprland/UPower data arrive async after start:
  use bindings, not timers, in probes. Probe scripts must end with
  `Qt.exit(0)` or their console output is lost when `timeout` kills them.
- `QtQuick.Effects` MultiEffect masks didn't apply; `Qt5Compat.GraphicalEffects`
  `OpacityMask` works (music title fade).
- Inside `ClippingRectangle`, children's `parent` is an inner container: use ids.
- In a `RowLayout` with a long-text column next to a control, give the column
  `Layout.preferredWidth: 0` + wrap, or the control is pushed out of view.
- Soft glows: `Shape` + `RadialGradient` on a `PathRectangle`; a rounded
  `Rectangle` with a gradient has a hard edge.
- Icon theme for Quickshell: `//@ pragma IconTheme Papirus-Dark` in `shell.qml`
  (read at startup only).
- Plain file paths as image sources need `file://`.
- PopupWindow / IconImage / tray: `QsMenuOpener` + `entry.triggered()` to
  build themed tray menus; `SystemTrayItem.display()` exists for native ones.

### 4.3 GPU / NVIDIA

- Open modules 595+: `nvidia-suspend/resume/hibernate` services are NOT needed
  (the package disables them). `PreserveVideoMemoryAllocations=2` means auto =
  on when `UseKernelSuspendNotifiers=1` (it is).
- Anything that queries the RTX 3050 wakes it from D3 (~1.6 s, battery):
  GTK4's default Vulkan renderer did this on every launch → `GSK_RENDERER=ngl`
  (hypr `env.lua` + `systemd/.config/environment.d`). The stats panel only calls
  `nvidia-smi` if `/sys/bus/pci/devices/0000:01:00.0/power/runtime_status` is
  already `active`. Check that path after adding anything GPU-related.
- `lsmod | grep -q` under `set -o pipefail` can fail via SIGPIPE: check
  `/sys/module/<name>` instead.
- Games run on NVIDIA via `prime-run`; frames are shown through the iGPU.

### 4.4 Audio

- WirePlumber remembers card profiles. The SOF card once got stuck on
  **"Pro Audio"** (no speaker routing → silence). Fix:
  `pactl set-card-profile alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)"`.
  The AudioMenu hides Pro Audio devices.
- PulseAudio/jack2 were replaced by pipewire-pulse/-jack during install.

### 4.5 Recording / capture

- gpu-screen-recorder encodes on the GPU driving the display (Intel Quick Sync
  here), even under `prime-run`. ~10 % CPU at 1080p60; dGPU stays asleep.
- `cliphist decode` needs the whole `id<TAB>content` line, not just the id.
- Screen freeze while selecting: `hyprpicker -r -z &` then `slurp`, then kill it.
- slurp colors come from the generated `scripts/theme-colors.sh`.

### 4.6 Wallpaper (awww)

- awww draws the wipe edge at (angle − 90°): angle 162 = edge leaning 18° like
  the reel's cards. Measured from mid-transition screenshots.
- The `.23,1,.32,1` bezier front-loads movement: capture at ~0.1–0.2 s.
- Thumbnails: `~/.cache/wallpaper-thumbs`, only rebuilt for new/changed files.

### 4.7 GTK / rofi / misc

- GTK4 user CSS (`~/.config/gtk-4.0/gtk.css`) can target Nautilus via
  `.nautilus-window`.
- Nautilus sidebar folders (Documents, Music, …) come from
  `~/.config/gtk-3.0/bookmarks`, written by `xdg-user-dirs-gtk-update`; GNOME
  runs it from XDG autostart, Hyprland doesn't → it's in `autostart.lua` +
  `install.sh`. The file holds absolute paths: never commit it (gitignored,
  gtk-3.0 is a no-fold dir). The Google Drive bookmark (step 16) goes there too.
- rofi custom widgets need a type prefix (`textbox-search`, `icon-…`).
- rofi `drun` sorts by usage history automatically when the query is empty.
- reflector config: multi-word country names get split; use codes (`IN,SG,BD`).
- `sed` with `|` inside the pattern as delimiter breaks; use Python for
  non-trivial edits (and don't chain the next step with `&&` blindly).
- Notifications: without a server, Firefox draws its own white popups.

- jq: `capture()` with no match yields *nothing* (not null/error), which
  silently empties a `reduce`; use `[ … | capture(…) ] | .[0]`.
- Markdown: backticks inside inline code need a double-backtick span.

### 4.8 qylock

- Pinned at c2933f2 in `~/.local/src/qylock` (GPL-3.0, not copied into this
  repo). `lock.sh` exports `QS_THEME` from `~/.config/qylock/theme`, runs
  `quickshell -p lock_shell.qml` (WlSessionLock + PAM). Its `hyprctl keyword`
  call is harmless in Lua mode (`allow_session_lock_restore` is set in look.lua).
- SDDM's Arch PAM file already has `pam_gnome_keyring` (auth + session).

---

## 5. Decisions that differ from the brief

| Brief | Built | Why |
|-------|-------|-----|
| `hyprland.conf` + `bindd` | `hyprland.lua` + `hl.bind{description}` | Hyprland 0.57 uses Lua |
| NVIDIA suspend services | not enabled | unnecessary with open modules 595+ |
| Recording with NVENC | Intel Quick Sync | gsr encodes on the display GPU (iGPU chosen) |
| Workspaces scroll to cycle | removed | user request |
| Cava wave in the bar (+ IdleScreen) | removed | 15–30 % CPU while playing; user scrapped it |
| Text sizes | Windows-125 % (15 px UI, GTK 11.25 pt, kitty 13 pt, Nautilus 12 pt); bar 44 px | user request |
| Theme | palette system + 5 themes (ALT+T) | user request |
| Replay toggled only from bar menu | ALT+Ctrl+R turns it on / saves; ALT+Ctrl+Shift+R toggles | indicator is hidden when idle |
| Bluetooth PIN confirm dialog | not possible in Quickshell (no agent) → "Advanced…" (Blueman) | missing API |
| Dim to ~30 % | 30 % of the *current* brightness | user usually at ~18 % |
| Wallpapers never created | default palette gradient only if folder empty | no blank screen on fresh install |
| Logout | `hyprshutdown` if installed | graceful app shutdown |
| Music title truncation | soft fade, 420 px | user request |

---

## 6. Known limitations / open items

- Bluetooth devices needing PIN/number confirmation: use Blueman (Advanced…).
  Possible later: a tiny BlueZ agent forwarding to Quickshell.
- notify-send with an unknown icon name shows Papirus' grey ✕ instead of the
  bell fallback.
- Tearing (`immediate`) for games is set but unverified with iGPU-scanout (step 19).
- Step 14 needs the user's qylock/SDDM runs + reboot before lock/SDDM/suspend
  are verified.
- Remaining build steps: 16–21 (Nautilus/GDrive/GTK/Qt, apps,
  Neovim, gaming, maintenance tooling/update.sh, README + license).

---

## 7. How to verify changes

- Hyprland: `Hyprland --verify-config -c ~/dotfiles/hypr/.config/hypr/hyprland.lua`,
  then `hyprctl reload; hyprctl configerrors`.
- Quickshell: `qs log | tail` (look after the last "Reloading configuration");
  for anything visual/CPU: clean restart (§4.2), exactly one instance
  (`pgrep -cx qs`).
- CPU: `P=$(pgrep -x qs); a=$(awk '{print $14+$15}' /proc/$P/stat); sleep 10; b=…;`
  ticks/10 ≈ %. Idle target: ~0 %. `top` snapshots were misleading.
- Visual: `grim -g "x,y wxh" file.png` (or `-s 0.5` for full screen) and look
  at it; open UI via IPC (`qs ipc call …`) rather than asking the user.
- dGPU: `cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status`
  (should be `suspended` when nothing uses NVIDIA).
- Shell scripts: `bash -n`; zsh startup: `script -qec 'zsh -i -c exit' /dev/null`
  (~80 ms).
- Root-step results: newest log in `~/.local/state/dotfiles/logs/`.

---

## 8. Recovery

- Desktop won't start: Ctrl+Alt+F3, log in, `cd ~/dotfiles`, `claude`.
- Bar gone: `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`, then `qs log`.
- Login screen broken: TTY, `sudo systemctl disable sddm.service && reboot`,
  then `start-hyprland` on tty1.
- Bad update: roll back to the snap-pac "pre" snapshot (ROOT-STEPS §1.6; if
  the kernel changed, `sudo pacman -S linux` after rollback).
- No sound: check the card profile (§4.4).
- Theme looks wrong: `theme/apply.sh blue-ice`.

---

## 9. Log

Newest first. Format: date — what broke / what changed, after which update,
root cause, fix, files.

- **2026-11-09** — Nautilus sidebar had no Documents/Music/Pictures/Videos/
  Downloads. Cause: `~/.config/gtk-3.0/bookmarks` never created (GNOME's
  autostart for `xdg-user-dirs-gtk-update` doesn't run under Hyprland). Fix:
  run it in autostart + install.sh. Files: `hypr/conf/autostart.lua`,
  `install.sh`, `packages/pacman.txt`.
- **2026-11-09** — Step 15: keybind cheat sheet (ALT+/) + README table
  generator, both from `scripts/keybinds.jq`.
- **2026-11-09** — Build steps 1–14 + theme system done (see `git log`).
  Versions in §1.
- **2026-11-09** — Replay mode couldn't be turned off from the bar. Cause: long
  description pushed the switch out of the popup. Fix: wrapping layout,
  "Turn off replay" button, ALT+Ctrl+Shift+R. Files: `bar/RecordingIcon.qml`,
  `services/Recorder.qml`, `keybinds.lua`.
- **2026-11-09** — Keybind-opened popups (ALT+N) could silently not appear.
  Cause: Wayland refuses grabbing popups without recent input on the parent.
  Fix: no-grab + HyprlandFocusGrab path. Files: `services/Popups.qml`,
  `popups/PopupFrame.qml`, `shell.qml`.
- **2026-11-09** — Cava wave cost 15–30 % CPU while music played (Canvas,
  Shapes, layered waves all tried). Removed at the user's request.
- **2026-11-09** — Music title was cut off abruptly: MultiEffect mask never
  applied. Fix: Qt5Compat OpacityMask. File: `bar/MediaModule.qml`.
- **2026-11-09** — Nautilus took 2.3 s to open. Cause: GTK4 Vulkan renderer woke
  the suspended RTX 3050. Fix: `GSK_RENDERER=ngl` (0.64 s). Files:
  `hypr/conf/env.lua`, `systemd/.config/environment.d/10-rice.conf`.
- **2026-11-09** — White "blob" popups: no notification server, Firefox's
  fallback. Fix: Quickshell NotificationServer. Files: `services/Notifications.qml`,
  `notifications/*`.
- **2026-11-09** — No sound from speakers. Cause: WirePlumber remembered the
  "Pro Audio" profile. Fix: HiFi (Speaker) profile via pactl (no repo change;
  AudioMenu hides Pro Audio devices).
- **2026-11-09** — reflector.service failed: "Sri Lanka" split on the space.
  Fix: country codes. File: `system/etc/reflector.conf`.
- **2026-11-09** — False NVIDIA check failures in root-steps script 3
  (`lsmod | grep -q` + pipefail SIGPIPE; `PreserveVideoMemoryAllocations=2`
  misread). Fix: `/sys/module` check, accept 2 with suspend notifiers.

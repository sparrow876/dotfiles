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

Recorded 2026-11-09 (build complete, steps 1–21; per-game setup waits for the games);
updated 2026-11-10 after the 82-package upgrade; kernel, NVIDIA, Mesa, rofi,
kitty rows refreshed 2026-11-24.
BIOS F.28, Intel ME 16.1.32.2418, SSD (Micron MTFDKBA512TFH) firmware HPS0043.
After an update, compare with `pacman -Q <pkg>` and update this table.

| Component | Version |
|-----------|---------|
| Kernel | linux 7.3.5-arch1-1 |
| Hyprland | 0.57.2 (Lua config) |
| Quickshell | 0.3.2 |
| NVIDIA | nvidia-open 620.73.04-1 / nvidia-utils 620.73.04-1 |
| Mesa | 26.3.1 |
| PipeWire / WirePlumber | 1.6.11 / 0.5.19 |
| awww (ex-swww) | 0.12.1 |
| hypridle | 0.1.8 |
| rofi | 2.1.1 (native Wayland) |
| kitty | 0.51.0 |
| gpu-screen-recorder | 6.1.7 |
| Steam / MangoHud / GameMode | 1.0.0.87 / 0.8.4 / 1.8.2 (gamescope 3.17.0) |
| SDDM | 0.21.0 (X11 greeter) |
| Neovim | 0.12.6 (plugins pinned in `nvim/.config/nvim/lazy-lock.json`) |
| zathura | 2026.10.23 (+ pdf-mupdf) |
| TeX Live | 2026 (basic, latexextra, fontsrecommended, binextra) |

Hardware: HP Victus 15 (fa0xxx), i5-12450H, Intel Alder Lake iGPU (`i915`,
drives eDP-1, `boot_vga=1`) + RTX 3050 Laptop (GA107, drives HDMI, sleeps in
runtime D3 when unused; NOT on kernel 7.3+ until NVIDIA fixes bug 7039712, see §6). eDP-1 1920x1080@144, no VRR. Battery `BAT0`, charger
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
   reboots; 2-nvidia, 3-system, 4-login and 5-trash-mounts log to
   `~/.local/state/dotfiles/logs/`, so read the newest log instead of asking
   for pasted output). Claude never runs these.
3. **`install.sh`** (user level): dirs, default wallpaper, pinned clones
   (Oh My Zsh + 2 plugins, qylock), GNU Stow, Qt config, gsettings.
   `./install.sh --packages` installs packages (user runs it).
4. **Stow packages**: top-level dirs mirroring `$HOME`. Only the ones listed in
   `STOW_PACKAGES` in `install.sh` are linked (a half-built package never
   replaces a working config). `NO_FOLD_DIRS` keeps dirs like `~/.config/gtk-3.0`
   real so app-written files (bookmarks) never land in the repo.
5. **Colours**: Blue Ice only, as plain per-app files (Theme.qml, colors.lua,
   kitty colors.conf, rofi colors.rasi, starship.toml, fzf-colors.zsh, bat
   rice.tmTheme, lazygit, fastfetch, MangoHud, qt*ct rice.conf, Vesktop css,
   rmpc rice.ron, qimgv/theme.conf, scripts/theme-colors.sh). The palette
   generator + theme switcher were removed 2026-11-22 (user request, §5);
   change a colour in each file that uses it.
6. **Runtime**: Hyprland (Lua) autostarts polkit agent, hypridle, awww +
   restore, Quickshell (`qs`), cliphist watchers, wl-clip-persist.

### 2.2 Directory map

| Path | Role |
|------|------|
| `hypr/.config/hypr/hyprland.lua` | only `require("conf.x")` lines |
| `hypr/.config/hypr/conf/` | `env` `monitors` `input` `look` `animations` `rules` `games` `keybinds` `autostart` (Lua) + `colors.lua` (Blue Ice colours, plain file) |
| `hypr/.config/hypr/hypridle.conf` | idle chain (hyprlang format, not Lua) |
| `quickshell/.config/quickshell/shell.qml` | entry: one `Variants` per screen for Bar, OSD, StatsPanel, PowerMenu, WallpaperReel, IdleScreen, CheatSheet, Overview, NotificationPopups; `popups` IPC |
| `quickshell/…/Theme.qml` | singleton: colors, fonts, sizes (plain file) |
| `quickshell/…/services/` | singletons: Audio, Bluetooth, Brightness, IdleInhibit, Keybinds, LayoutMode (spaced/compact), Media, Network, Notifications, Overlays (IPC for the per-monitor overlays), Popups, Power (battery + low-battery warnings), Recorder, SystemStats (+`sysstats.sh`, `cputemp.sh`), Wallpapers |
| `quickshell/…/bar/` | Bar + modules (`*Icon.qml`, Workspaces, MediaModule, Battery, Clock, Tray, TrayMenu, Bell) |
| `quickshell/…/popups/` | `PopupFrame` (shared) + Network/Bluetooth/Audio/Brightness menus, Calendar, MediaCard (now playing) |
| `quickshell/…/notifications/` | popups + center |
| `quickshell/…/components/` | StyledText, Icon, Glyphs (all glyphs), Tooltip, Toggle, Slider, IconButton, TextButton, Card, Spinner, Separator, LevelBar, Graph, RingGauge, WheelSteps (scroll → whole steps) |
| `quickshell/…/{osd,panel,powermenu,wallpaper,idle,cheatsheet,overview}/` | one overlay each |
| `scripts/` | shell helpers (update, wifi-enterprise, screenshot, ocr, colorpick, clipboard, emoji, lock, logout, idle-dim, idle-suspend, lid, wallpaper, record, notify-file, qt-config, qimgv-theme, view-all-images, calc, find-file, layout-mode, lockdir + lockdir-gui, latex-ocr/, ccmonitor/, keybinds-to-md.sh + keybinds.jq, theme-colors.sh) |
| `system/` | ROOT-STEPS.md, root-steps scripts, units (platform profile, paccache), etc (reflector.conf, logind.conf.d/10-lid.conf) |
| `systemd/` | `environment.d/10-rice.conf` (env before Hyprland starts), `systemd/user/rclone-gdrive.service`, drop-ins `mpd.service.d/runtime-dir.conf` and `mpdris2-rs.service.d/override.conf` |
| `applications/` | `.desktop` files: Outlook web app, nvim in kitty, rmpc |
| `xdg/` | `hyprland-mimeapps.list` (default apps) |
| `qt/` | qt5ct/qt6ct colour files (Blue Ice) |
| `vesktop/` | Vesktop theme `rice.theme.css` (Blue Ice) |
| `zsh/`, `kitty/`, `starship/`, `fastfetch/`, `lazygit/`, `bat/`, `rofi/`, `gtk/` | app configs (stowed) |
| `nvim/` | Neovim (Nord): `init.lua`, `lua/{options,keymaps,autocmds}.lua`, `lua/plugins/*.lua` (one file per topic), `lazy-lock.json`; `CHEATSHEET.md` (not stowed) |
| `zathura/` | zathurarc (Nord, SyncTeX, recolor on Ctrl+R, glass on Ctrl+G: glass-on/off.conf + git-ignored glass.conf link, bin/.local/bin/zathura-glass, Hyprland rule "zathura-glass" in hypr/conf/rules.lua) |
| `mangohud/` | MangoHud.conf (Blue Ice colours) |
| `gamemode/` | `gamemode.ini` (renice, screensaver inhibit) |
| `thumbnailers/` | `pdf.thumbnailer` (PDF thumbnails in Nautilus via pdftoppm) |
| `nautilus/` | nautilus-python extensions: Copy as Path, View All Images, Lock Folder |
| `bin/` | `~/.local/bin` commands: ccmonitor, lockdir / unlockdir, view-all-images, zathura-glass |
| `mpd/`, `rmpc/` | MPD config (`~/Music`, 127.0.0.1:6600) and rmpc (config + `rice.ron` theme) |
| `makepkg/` | `~/.config/pacman/makepkg.conf` (no -debug packages) |
| `qimgv/` | qimgv theme (applied by `scripts/qimgv-theme.sh`) |
| `system/GAMING.md` | Steam setup, launch options, controller, per-game notes |

### 2.3 Quickshell IPC targets (`qs ipc call <target> <fn>`)

| Target | Functions | Used by |
|--------|-----------|---------|
| `popups` | `toggle <network\|bluetooth\|audio\|brightness\|calendar\|notifications\|recording\|media>`, `close` | ALT+N |
| `panel` | `toggle` | ALT+S |
| `powermenu` | `toggle` | ALT+Escape |
| `wallpaper` | `toggle` | ALT+W |
| `wallpapers` | `refresh`, `list` | debugging |
| `idle` | `toggle`, `status` | ALT+I (coffee cup) |
| `idlescreen` | `enter`, `leave` | hypridle via `scripts/idle-dim.sh` |
| `cheatsheet` | `toggle` | ALT+/ |
| `overview` | `toggle`, `open`, `close` | ALT+A, 3-finger swipe up (open) / down (close) |
| `notifications` | `dnd`, `clear`, `status`, `clickLatest` | — |
| `recorder` | `toggleFull`, `toggleRegion`, `replay`, `toggleReplay`, `toggleMic`, `status` | ALT+R, ALT+Shift+R, ALT+Ctrl+R, ALT+Ctrl+Shift+R |
| `audio` | `devices` | debugging |

### 2.4 Keybinds

All in `hypr/.config/hypr/conf/keybinds.lua`, each with a
`description = "Category: Action"` (this replaces the brief's `bindd`; visible
in `hyprctl binds -j`). `scripts/keybinds.jq` turns that JSON into grouped,
readable rows (merges alternatives, collapses `1…9`); it feeds BOTH the cheat
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
never twice; hides the IdleScreen 2 s later) → 360 s DPMS off → 1200 s
`scripts/idle-suspend.sh start`: suspends only while the battery reports
`Discharging` (USB-C PD charging counts as AC), re-checking every 30 s while
idle; `stop` on input. `inhibit_sleep = 3`: logind waits until the session is
really locked before sleeping (hypridle's default only does that for hyprlock).
Lid (logind, `system/etc/logind.conf.d/10-lid.conf`, ROOT-STEPS §14): plugged
in → lock only; battery → suspend; external monitor → nothing. Hyprland's
`switch:on/off:Lid Switch` binds (keybinds.lua) turn eDP-1 off/on with the lid.
Inhibited by: coffee cup (IdleInhibitor on the bar surface), fullscreen
(`idle_inhibit = "fullscreen"` window rule), D-Bus/systemd inhibitors (calls).

### 2.7 Updates, timers, firmware

**`update`** (`scripts/update.sh`, alias in `zsh/.config/zsh/aliases.zsh`):
Arch news since the last "full system upgrade" in pacman.log (python, RSS;
STOPS with a y/N prompt if a manual-intervention item names an installed
package or names none it can recognise) → `checkupdates` + `yay -Qua` with a
watch list (kernel/NVIDIA/firmware/mesa/systemd = reboot; Hyprland/Quickshell/
Qt/SDDM/audio = log out) → `yay -Syu` (snap-pac pre/post snapshots) → reboot /
log-out hint, `Hyprland --verify-config` if Hyprland changed, the "pre"
snapshot number → housekeeping: `pacdiff -o`, `pacman -Qdtq`, explicitly
installed packages missing from `packages/{pacman,aur,base}.txt`, failed
units, `fwupdmgr get-updates`. `update --check` = everything but the upgrade
(safe for Claude to run). History: `~/.local/state/dotfiles/update.log`.
`packages/base.txt` = archinstall/bootstrap packages (globs ok), only for that check.

| Timer | Does | Set up in |
|-------|------|-----------|
| `snapper-timeline` / `snapper-cleanup` | hourly/daily home snapshots (root has TIMELINE_CREATE=no); cleanup prunes home + root by limits | ROOT-STEPS §1 |
| snap-pac (pacman hook, not a timer) | pre/post snapshot around every pacman transaction | ROOT-STEPS §1 |
| `paccache.timer` | weekly, keeps the last 2 versions of each package | ROOT-STEPS §6 |
| `reflector.timer` | weekly: the 20 most recently synced HTTPS mirrors (IN, SG, BD), sorted by speed | ROOT-STEPS §6 |
| `archlinux-keyring-wkd-sync.timer` | keyring refresh (Arch default) | — |
| (no fstrim.timer) | not needed: btrfs mounts with `discard=async` | — |

Check: `systemctl list-timers`. Firmware: fwupd sees BIOS, ME, SSD, Secure
Boot DBs; `fwupdmgr refresh` is allowed without a password (polkit
`refresh-remote`). HP publishes nothing for this model on LVFS so far (BIOS
updates via HP's own updater).

**After an update breaks something** (CLAUDE.md §30): `grep -E 'upgraded|installed'
/var/log/pacman.log | tail -40`, `~/.local/state/dotfiles/update.log`,
`snapper -c root list | tail` (the "pre" snapshot = before the update),
Arch news, this file's §9. Rollback: ROOT-STEPS §1.6.

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
  + no-anim layer rule), add a `Variants` in `shell.qml`, a property + an
  `IpcHandler` in `services/Overlays.qml` (NOT in the per-screen file, §4.2),
  a `Connections { target: Overlays }` in the overlay, and a keybind.
- **New keybind**: `bind(keys, dispatcher, "Category: Action", opts)` in
  `keybinds.lua`; run `Hyprland --verify-config`; regenerate the README table
  (`scripts/keybinds-to-md.sh README.md`). Unusual key names: add to `prettykey`.
- **New window rule**: `hl.window_rule({ name, match = {…}, effect = … })` in
  `rules.lua`; effect names from §4.1.
- **New stow package**: create `<pkg>/<path under $HOME>`, add `<pkg>` to
  `STOW_PACKAGES`, `./install.sh --only stow`. If apps write into that dir,
  add it to `NO_FOLD_DIRS`.
- **New app colours**: use the Blue Ice hexes from CLAUDE.md §5 (QML: the
  `Theme.*` properties, scripts: `scripts/theme-colors.sh`).
- **New package**: verify name (`pacman -Si` / `yay -Si`), add to the right
  group in `packages/*.txt`; AUR: read the PKGBUILD first and note it inline.
- **New root action**: document in ROOT-STEPS (command, what it does, undo);
  for long blocks, a script in `system/root-steps/` with the logging wrapper.
- **Text sizes**: Quickshell `Theme.qml` (fontSize 15 / fontSizeSmall 13), rofi
  `config.rasi`, GTK via `install.sh` gsettings, kitty in `kitty.conf`, Nautilus in `gtk-4.0/gtk.css`.
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
- **Restart**: `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
  Never `qs kill` (stops one instance only → duplicates stack up). Restart for visual/CPU checks (hot reload keeps stale
  layer sizes). A restart clears notification history and stops replay mode.
- **Hot reload** (any .qml save) recreates all singletons
  and does NOT stop child processes: state that must survive goes in
  `PersistentProperties { reloadableId }` (coffee cup, DND); long-running
  children are stopped in `Component.onDestruction` and started via
  `setpriv --pdeathsig <SIG>` so they also die if qs is killed/crashes
  (udevadm, gpu-screen-recorder).
- **IpcHandler inside a per-screen `Variants` delegate only works on the first
  monitor** ("another handler is registered for target"). Overlay IPC lives in
  `services/Overlays.qml`; overlays react via `Connections` (a `wanted`
  binding + writing back to Overlays in close() = binding loop).
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
- Icon theme for Quickshell: `//@ pragma IconTheme Papirus-Dark` in shell.qml
  (read at startup only; it overrides the `QS_ICON_THEME` env var). The theme
  is dark, so it never changes.
- Touchpads send many small wheel events: use `WheelSteps` (120 units = one
  step); never step once per `onWheel`.
- Hover on a card with buttons: `HoverHandler` on the card (a sibling
  `MouseArea` underneath loses hover to the buttons).
- UPower `displayDevice` has no health (0, unsupported): use the device with
  `isLaptopBattery` (BAT0), `healthPercentage` is 0..100. A probe must touch
  `UPower` at load time or the device list stays empty.
- `findmnt -r` hex-escapes spaces (`\x20`) → invalid JSON; use `findmnt -J`.
- Plain file paths as image sources need `file://`.
- PopupWindow / IconImage / tray: `QsMenuOpener` + `entry.triggered()` to
  build themed tray menus; `SystemTrayItem.display()` exists for native ones.

### 4.2b Neovim / LaTeX

- Headless Neovim reads stdin: always `nvim --headless … </dev/null` or it
  hangs. Install/update from a shell: `nvim --headless "+Lazy! sync" +qa </dev/null`;
  parsers: `require('nvim-treesitter').install({...}):wait(300000)`; servers:
  `nvim --headless -c "Lazy! load mason.nvim" -c "MasonInstall <pkgs>" -c qa`
  (blocks until done). `+qa` right after `Lazy! sync` cuts treesitter's async
  compiles short (re-run the install line).
- nvim-treesitter is the `main` branch (new API: `install()`, FileType autocmd
  + `vim.treesitter.start`); not lazy-loadable. LaTeX uses vimtex's own syntax.
- vimtex `view_method = "zathura_simple"`: plain `zathura` needs xdotool (X11).
  Forward search goes over zathura's D-Bus; inverse search (Ctrl+click) runs
  `nvim --headless -c VimtexInverseSearch …`, which finds the editor through
  vimtex's server-name cache. Test without clicking: start
  `nvim --headless --listen sock file.tex`, run that command, query
  `line(".")` with `nvim --server sock --remote-expr`.
- vimtex opens zathura automatically after the first successful compile.
- Kitty opacity: autocmds call `kitty @ --to $KITTY_LISTEN_ON set-background-opacity`
  (1 in Neovim, 0.80 after) and paint kitty's padding with the colorscheme
  background via OSC 11 (`vim.api.nvim_ui_send`), reset with OSC 111 on exit.
  Verify by sampling pixels with grim (padding = exactly `#2E3440` in nvim).
- blink.cmp uses the Lua fuzzy matcher (no prebuilt binary download);
  `:checkhealth` warns about that, expected.

### 4.2c Network (NetworkManager)

- Enterprise Wi-Fi (PEAP + MSCHAPv2, e.g. IISc `iiscwlan`, eduroam):
  `scripts/wifi-enterprise.sh [ssid]`, also opened by the Wi-Fi menu's
  "Set up…" (kitty class `wifi-setup`, floating rule in rules.lua). Prompts for
  username/password (hidden) and a CA certificate; stores a system connection
  with `802-1x.password-flags 0` (no secret agent runs here: there is no
  nm-applet, so agent-owned secrets would never be supplied). CA copied to
  `~/.local/share/certs/<ssid>-ca.pem`. The wheel group may add system
  connections without a password (NetworkManager's polkit rule).
- iiscwlan (IISc DIGITS Linux guide): PEAP auto, MSCHAPv2, username = IISc
  email, password = IISc email password. The guide says "No CA certificate is
  required"; we validate anyway with IISc's Wi-Fi CA
  (digits.iisc.ac.in/tina/wi-fi-ca, IISc login). Server cert subject shows in
  `journalctl -u wpa_supplicant | grep "depth=0 subject"` → can be pinned with
  `nmcli connection modify iiscwlan 802-1x.domain-suffix-match <name>`.
- Diagnose a failed connection: `journalctl -u NetworkManager -u wpa_supplicant
  --since -10min` (no passwords in these logs).

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

### 4.3b Gaming

- Games run on the RTX 3050 only with `prime-run` in the Steam launch options
  (`prime-run gamemoderun mangohud %command%`); env vars go before `prime-run`.
- MangoHud's `gpu_name` line shows the GPU the app really uses; `pci_dev=0000:01:00.0`
  limits the stat rows to the RTX 3050 (two GPUs otherwise: GPU0/GPU1).
- Testing: `vkcube` picks the discrete GPU by itself (use `--gpu_number 0` for
  Intel); under Wayland it has no app id (match it by title "vkcube").
- Tearing verified with this hybrid setup: fullscreen `immediate` window from
  `prime-run vkcube --present_mode 0` → `hyprctl monitors -j` activelyTearing true.
- A temporary rule at runtime: `hyprctl dispatch 'hl.window_rule({...})'` prints
  "expected a dispatcher" but registers the rule; `hyprctl reload` removes it.
- GameMode needs the `gamemode` group (polkit rule + `nice -10` limit); without
  it governor changes ask for a password. Check: `gamemoded -s` while playing.
- 8BitDo Ultimate 2C wired (`2dc8:310a`): xpad, uaccess ACL on `/dev/input/event*`
  (no extra udev rules); standard Xbox layout only (see GAMING.md §5).
- The Steam folder `~/.local/share/Steam` is its own btrfs subvolume (inode 256):
  outside home snapshots. New library folders need `mksubvol` first.

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
- slurp colors come from `scripts/theme-colors.sh`.

### 4.6 Wallpaper (awww)

- awww draws the wipe edge at (angle − 90°): angle 162 = edge leaning 18° like
  the reel's cards. Measured from mid-transition screenshots.
- The `.23,1,.32,1` bezier front-loads movement: capture at ~0.1–0.2 s.
- Thumbnails: `~/.cache/wallpaper-thumbs`, only rebuilt for new/changed files.
- Reel apply (WallpaperReel.qml): the focused card grows to full screen with the
  picture decoded at screen size (same centre crop as `awww --resize crop`),
  `wallpaper.sh apply <file> --cover <output>` switches that output instantly
  (`-t none`) behind it (other outputs get the wipe), and the wipe starts only
  when the grow is done, the sharp picture is decoded and awww has exited
  (4 s safety timer). The wipe is an 18°-sheared `clip` Item with counter-
  sheared content; clip is on only while applying.
- The reel loops only with 5+ wallpapers (fewer would show the wrap seam);
  with fewer, moving past the end glides back to the start.
- A hot reload that adds an inline component (`component X: ...`) failed with
  "X is not a type" in a qs that had been running ~2 days; a fresh `qs` loaded
  the same file and later reloads were fine.

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
- Never set `drun-use-desktop-cache: true`: rofi doesn't refresh it, so removed
  apps linger and new ones (Teams, Vesktop, Claude) never appear.
- reflector config: multi-word country names get split; use codes (`IN,SG,BD`).
- `sed` with `|` inside the pattern as delimiter breaks; use Python for
  non-trivial edits (and don't chain the next step with `&&` blindly).
- Notifications: without a server, Firefox draws its own white popups.

- jq: `capture()` with no match yields *nothing* (not null/error), which
  silently empties a `reduce`; use `[ … | capture(…) ] | .[0]`.
- Markdown: backticks inside inline code need a double-backtick span.

- Nautilus is Nord via libadwaita CSS *variables* scoped to `.nautilus-window`
  in `gtk/.config/gtk-4.0/gtk.css` (libadwaita ≥ 1.6); other GTK4 apps follow
  the theme. Dialogs opened as separate windows (Properties) stay Adwaita.
- Default apps live in `xdg/.config/hyprland-mimeapps.list` (read before
  `mimeapps.list` because XDG_CURRENT_DESKTOP=Hyprland). Apps rewrite
  `~/.config/mimeapps.list` and would break a stowed symlink, so that file stays
  user-owned. Check with `gio mime <type>`.
- Qt: qt5ct/qt6ct, Fusion + `qt/.config/qt*ct/colors/rice.conf` (Blue Ice);
  `scripts/qt-config.sh` writes `qt*ct.conf` (absolute path → not committed) on
  install (`./install.sh --only qt`). Kvantum Manager always draws in Kvantum's own style,
  so it's useless for checking the palette; use `qt6ct`.
- Hyprland reuses window addresses right away: when testing windows, wait for
  the old one to disappear before diffing addresses for the next one.

- Chromium **ignores `--class` on Wayland**: an `--app=` window's class is
  `chrome-<host+path, / -> _>-<profile>` (Outlook: `chrome-outlook.office.com__mail_-Default`).
  Changing the URL or profile changes the class (update rules + StartupWMClass).
- `.desktop` Exec quoting: only double quotes; `$`, `"` inside need `\\$`,
  `\\"`. Check with `desktop-file-validate`.
- Notification click → focus: apps can't raise themselves
  (`focus_on_activate = false`), so `Notifications.focusApp()` matches
  `desktop-entry`/app name to a Wayland toplevel `appId` and calls
  `Toplevel.activate()` (switches workspace too). Test:
  `qs ipc call notifications clickLatest`.
- `install.sh` stow backups: dirs in `NO_FOLD_DIRS` are treated as shared
  (per-file backup), otherwise generated real files (qt*ct.conf) made it move
  the whole dir, after which stow *folded* it into a repo link and
  the Qt helper wrote absolute-path configs into the repo (removed, now
  gitignored). After any stow change: `ls -la ~/.config | grep -- '->'` and
  check no-fold dirs are real directories.

### 4.8 qylock

- Pinned at c2933f2 in `~/.local/src/qylock` (GPL-3.0, not copied into this
  repo). `scripts/lock.sh` sets QML2_IMPORT_PATH / QS_THEME / QS_THEME_PATH
  itself and runs `quickshell -p lock_shell.qml` (WlSessionLock + PAM); theme =
  `$1`, `LOCK_THEME` or winter (`allow_session_lock_restore` is set in look.lua).
- SDDM's Arch PAM file already has `pam_gnome_keyring` (auth + session).
- **Patched** (GPL patch `lockscreen/patches/qylock-lockscreen.patch`, applied
  by `lockscreen/apply-patches.sh`, also run by install.sh step clones): the
  lock screen's PAM shim. Re-run after qylock's `quickshell.sh`; `--revert`
  before bumping the pinned commit. The lock screen uses PAM service `login`
  → system-auth → pam_faillock (defaults: 3 failures in 15 min → 10 min lock,
  `faillock --user $USER --reset` clears it; needs root).
- qylock's own `lock.sh` is not used: it ignores `~/.config/qylock/theme`
  (always "winter" unless a theme is passed as the first argument).

---

## 5. Decisions that differ from the brief

| Brief | Built | Why |
|-------|-------|-----|
| `hyprland.conf` + `bindd` | `hyprland.lua` + `hl.bind{description}` | Hyprland 0.57 uses Lua |
| NVIDIA suspend services | not enabled | unnecessary with open modules 595+ |
| Recording with NVENC | Intel Quick Sync | gsr encodes on the display GPU (iGPU chosen) |
| Workspaces scroll to cycle | removed | user request |
| Music: click = play/pause, scroll = next/previous | click = play/pause, middle-click = now-playing card, no scroll-to-skip | user request 2026-11-22: players start playback on Next, so skipping while paused kept leaking playback with fast scrolling |
| Cava wave in the bar (+ IdleScreen) | removed | 15–30 % CPU while playing; user scrapped it |
| Text sizes | Windows-125 % (15 px UI, GTK 11.25 pt, kitty 13 pt, Nautilus 12 pt); bar 44 px | user request |
| Theme | Blue Ice only, plain per-app colour files; the palette generator + ALT+T switcher (4 themes) were removed 2026-11-22 (brief §4 `theme/render.sh` no longer applies) | user request: only ever used Blue Ice |
| Replay toggled only from bar menu | ALT+Ctrl+R turns it on / saves; ALT+Ctrl+Shift+R toggles | indicator is hidden when idle |
| Bluetooth PIN confirm dialog | blueman-applet is the pairing agent (no tray icon): code confirmations arrive as notifications with Confirm/Deny, PIN entry as a small dialog | Quickshell has no agent API |
| Bar right side order | tray (drag to reorder, Pomoclock pinned last) · layout button · idle · recording · Wi-Fi · Bluetooth · audio · **brightness** · battery · bell · clock | user request 2026-11-13; brief had tray · recording · idle · … (no brightness) |
| Music position | centred when it fits, else slid into the gap between workspaces and tray, using all of it (max 420 px title) | the wide Pomoclock pill left only ~160 px around the centre |
| Dim to ~30 % | 30 % of the *current* brightness | user usually at ~18 % |
| Wallpapers never created | default palette gradient only if folder empty | no blank screen on fresh install |
| Logout | `hyprshutdown` if installed | graceful app shutdown |
| Music title truncation | soft fade, 420 px | user request |
| Nord GTK3 theme (e.g. Nordic) | not installed; Nautilus (GTK4) is Nord via scoped CSS, GTK3 dialogs use Adwaita-dark | Nordic AUR last updated 2022; a global GTK3 theme would clash with the Nord Nautilus CSS |
| Qt via Kvantum | qt5ct/qt6ct Fusion + Blue Ice palette (Kvantum installed, unused) | Kvantum needs an SVG theme |
| Default apps in `mimeapps.list` | `hyprland-mimeapps.list` | apps rewrite mimeapps.list (breaks stow) |
| Touchpad natural scroll | normal (traditional) scrolling | user's choice, 2026-11-09 |
| Lid close → lock + suspend | plugged in: lock only; battery: suspend | user's choice, 2026-11-09 (downloads keep running) |
| Electron apps native Wayland | Teams stays XWayland (package's --ozone-platform=x11) | screen sharing risk; no blur at 1x scale |
| Qt5 apps themed | only Qt6 (QT_QPA_PLATFORMTHEME=qt6ct) | no Qt5 apps installed; if one appears, launch it with QT_QPA_PLATFORMTHEME=qt5ct |

---

## 6. Known limitations / open items

- **mpdris2-rs 1.1.2 breaks on MPD `single: oneshot`** (2026-11-23): drops its
  MPD connection on every event while single=oneshot, so the bar stops
  updating. Avoided by rmpc `v` = ToggleSingleOnOff; any other client setting
  oneshot (e.g. `mpc single oneshot`) brings it back. Real fix = treat
  "oneshot" as single on in `MpdLoopState::from_mpd` (src/mpd/types.rs).
  Reported 2026-11-23: https://github.com/szclsya/mpdris2-rs/issues/34 — once
  a release fixes it, remove this item (rmpc `v` can stay on/off). Upstream is
  slow but alive (last release 1.1.2 on 2026-06-30, issues closed up to
  2026-08-16). If #34 has no reply by ~2027-02, compare other MPRIS bridges
  (mpd-mpris froze on big embedded covers, see 2026-11-22).
- **Built-in webcam absent: hardware** (user confirmed, 2026-11-16). Never on
  the USB bus in any boot since install; most likely its connector/cable after
  a hinge repair. Internal digital mic works. Don't debug drivers for it; once
  repaired it should simply appear in `lsusb` (uvcvideo is built in).
- **RTX 3050 never powers off on kernel 7.3+** (since 2026-11-13): NVIDIA bug
  7039712 / https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1507
  (fix PR #1512). User chose to wait for the official fix (no workaround).
  After each kernel or nvidia-open update, check
  `cat /proc/driver/nvidia/gpus/0000:01:00.0/power` → "Runtime D3 status:
  Enabled (fine-grained)" and `power/runtime_status` → suspended when idle;
  then remove this item. Quick source check for a new driver release:
  `curl -s https://raw.githubusercontent.com/NVIDIA/open-gpu-kernel-modules/<tag>/kernel-open/nvidia/nv-pci.c | grep -c init_fs`
  (> 0 = fix included). Last checked 2026-11-19: linux 7.3.4.arch1-2 +
  nvidia-open 620.70.06-3 (both rebuilds) still "Disabled by default";
  NVIDIA's new 620.73.04 (2026-11-18) does NOT contain it; PR #1512 still open.
  Rechecked 2026-11-21 on linux 7.3.5.arch1-1 + nvidia-open 620.73.04-1:
  still "Disabled by default", 0 ms suspended. PR #1512 unmerged; two Arch
  users report 620.73.04 + #1512 rebuilt locally (nvidia-open-dkms) fixes it.
- Bluetooth PIN / code confirmation is handled by blueman-applet (the pairing
  agent, since 2026-11-11): notifications with Confirm/Deny or a PIN dialog, not
  inside the bar menu itself.
- notify-send with an unknown icon name shows Papirus' grey ✕ instead of the
  bell fallback.
- Games: ACC and MGSV installed and run (standard launch options); ACC's LAN
  ufw rules, serverList.json and controller setup are postponed; BeamNG and AC
  not installed yet (GAMING.md §7).
- Open items: rclone sign-in (`rclone config`), Teams/Vesktop call pop-out
  titles for the `call-popouts` rule, Vesktop theme visual check, one
  suspend/resume test with NVIDIA, docked lid-close test (scripts/lid.sh).
- Notification history is capped at 100 (oldest dropped).

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
- Bar gone: `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`, then
  `qs log`. From a TTY, hyprctl needs the instance: `hyprctl -i 0 dispatch ...`.
- Lock screen crashed/frozen: TTY (Ctrl+Alt+F3), `pkill -f
  'quickshell-lockscreen/lock_shell\.qml'` (else lock.sh's "already locked"
  check skips the relaunch), `hyprctl -i 0 dispatch
  'hl.dsp.exec_cmd("~/dotfiles/scripts/lock.sh")'`, back with Ctrl+Alt+F1/F2,
  unlock (`misc.allow_session_lock_restore` lets a new lock client take over).
  Don't run lock.sh directly in the TTY. Last resort: `hyprctl -i 0 dispatch
  'hl.dsp.exit()'`. Cause: `qs log` / journal.
- Login screen broken: TTY, `sudo systemctl disable sddm.service && reboot`,
  then `start-hyprland` on tty1.
- Bad update: roll back to the snap-pac "pre" snapshot (ROOT-STEPS §1.6; if
  the kernel changed, `sudo pacman -S linux` after rollback).
- No sound: check the card profile (§4.4).
- Qt apps / qimgv lost their colours: `./install.sh --only qt`.

---

## 9. Log

Newest first. Format: date — what broke / what changed, after which update,
root cause, fix, files.

- **2026-11-24** — zathura glass, part 2 (user: "even the text should be see
  through"). zathura can only make backgrounds transparent (dark-mode colours
  take alpha; a normal page is a solid image), so the whole window is now drawn
  at 90% by a named Hyprland rule "zathura-glass" (rules.lua; enabled at config
  load unless glass.conf's first line says "glass OFF"). zathura-glass flips it
  live: `hyprctl eval 'hl.window_rule({ name = "zathura-glass", enabled = ... })'`
  (re-calling a named rule updates it and refreshes window states, so open
  windows follow). glass-on.conf backgrounds raised (0.90 / 0.94 / 0.97, dark
  page 0.95) so with the 90% window they end near kitty's 0.80. Checked with
  `hyprctl getprop <addr> opacity|opacity_inactive`: on 0.9/0.9, off 1/1,
  toggling both ways; the rules.lua check run in lua against both files.
  Files: hypr/conf/rules.lua, glass-on/off.conf, zathura-glass, zathurarc,
  nvim/CHEATSHEET.md.

- **2026-11-24** — zathura glass (asked for: slight translucency, toggleable).
  Ctrl+G toggles slightly see-through backgrounds (default-bg 0.82, bars 0.86,
  dark-mode page 0.90; normal pages stay solid); Hyprland blurs behind it as
  for kitty. The choice is the link ~/.config/zathura/glass.conf ->
  glass-on.conf / glass-off.conf (git-ignored; zathurarc includes
  glass-off.conf then glass.conf). zathura's `include` can't use ~ or reach
  ~/.local/state (relative paths go through the stow symlink), hence the link
  in the package. bin/.local/bin/zathura-glass flips the link and applies the
  `set` lines to every open window over D-Bus (ExecuteCommand); Ctrl+G =
  `feedkeys ":exec zathura-glass<Return>"`. ExecuteCommand returns true even
  for unknown options, so checks used `:dump <file>` (JSON): link off/on +
  SourceConfig and `exec zathura-glass` twice gave the expected values.
  install.sh creates the default link (on). Files: zathurarc, glass-on.conf,
  glass-off.conf, bin/.local/bin/zathura-glass, install.sh, .gitignore,
  nvim/CHEATSHEET.md.

- **2026-11-23** — Bar music widget glitched again; the now-playing card's loop
  button disagreed with rmpc. Cause: rmpc's `v` (ToggleSingle) cycles single
  off -> **oneshot** -> on, and mpdris2-rs 1.1.2 only parses single as 0/1
  (src/mpd/types.rs `mpd_num_to_bool`): every MPD event while single=oneshot
  failed with "invalid field single: expect 0/1, got oneshot" and it dropped the
  connection, so the bar got no track or loop updates. Fix: `v` ->
  ToggleSingleOnOff (rmpc's own on/off action, skips oneshot); MPD's state moved
  from repeat 1 + single oneshot to repeat 1 + single 1 (same: loops the song).
  Checked both ways: MPD repeat/single changes -> MPRIS LoopStatus
  (Playlist/None/Track) and LoopStatus set over MPRIS -> MPD, no errors.
  Consume oneshot (`c`) is harmless (the bridge doesn't read consume).
  It also broke headphone auto-pause (ACCENTUM Plus off/on -> AVRCP key ->
  `playerctl play-pause`): the bridge's PlayPause sends "play" when its cached
  state is Stopped, and with every status parse failing that state was stale.
  Logged after the fix: each off/on = one PlayPause, MPD paused/resumed.
  Upstream: szclsya/mpdris2-rs#34 (see §6). Files: rmpc/.config/rmpc/config.ron.

- **2026-11-23** — Stats panel CPU temperature jumped between ~40 and ~80 °C.
  Not a faulty sensor: sampled every 10 ms from the uncached x86_pkg_temp zone,
  the package temperature went 45 -> 73 °C in ~60 ms on a short burst and back
  to 44 in ~250 ms (87 °C peak in 8 s of near-idle): the sensor is in the die,
  whose hot spot has almost no thermal mass, while the copper cooler stays at
  ~40. The panel showed one snapshot per 1.5 s refresh (coretemp's hwmon value,
  cached up to 1 s), so it landed on spikes at random. Fix: new
  services/cputemp.sh samples x86_pkg_temp every 100 ms (bash builtins only, so
  sampling doesn't cause bursts) and prints mean + max per 1.5 s window; it runs
  only while the panel is open (checked: gone after closing). The panel shows
  the mean (warn colours use it too) and "1-min peak" under it. Files:
  services/cputemp.sh (new), SystemStats.qml, panel/StatsPanel.qml,
  sysstats.sh (comment).

- **2026-11-23** — Wallpaper reel reworked (asked for: cooler look, looping, a
  cooler way for the new wallpaper to appear). Reel: loops (5+ wallpapers);
  backdrop = the focused wallpaper blurred + vignette, crossfading as you move;
  cards fly in staggered on open; neighbours shorter; pictures slide inside the
  cards (parallax); soft glow + one glint on the focused card; name, n / total
  and position pips. Apply: the card straightens and grows to fill the screen,
  awww switches the real wallpaper hidden behind it, then an 18° wipe with a
  glowing edge reveals the desktop. Every animation runs once (nothing loops
  while it sits open). Tested in a separate qs instance with an opaque stand-in
  for the desktop (frames captured at each stage), then live. Files:
  wallpaper/WallpaperReel.qml, services/Wallpapers.qml (url()),
  scripts/wallpaper.sh (`apply <file> --cover <output>`), README + screenshot.

- **2026-11-22** — Window border flickered on workspace switch and on opening a
  window. Cause (Hyprland 0.57.2 source, AnimatedDecorationGradient.cpp): the
  `borderangle` "once" turn (a full 360°) starts on window map and on every
  focus change, and a workspace switch focuses that workspace's window. At
  1.4 s with easeInOutCubic it peaked at ~700°/s, so the 5-colour aurora
  (added today) flashed past each corner several times a second. Fix: same
  turn over 5 s with a new easeInOutSine curve (peak ~115°/s), so it drifts
  instead. Colours unchanged. Files: hypr/conf/animations.lua, look.lua (comment).

- **2026-11-22** — mpdris2-rs switch verified (user installed it, disabled
  mpd-mpris, removed the package). Running as `mpdris2-rs --host
  127.0.0.1:6600 --no-notification` (override applied), bus name
  org.mpris.MediaPlayer2.mpd, covers in $XDG_RUNTIME_DIR/mpd/album_art/, MPD's
  socket intact. Test: jumped MPD to "STATE OF AFFAIRS" (play + pause in one
  command list) → MPRIS reported it, with the 3000×3000 / 5.2 MB cover, after
  0.7 s (mpd-mpris: 7.5 s+ and stuck); then restored the user's song and
  position. Files: none (verification).

- **2026-11-22** — Bar music / now-playing card froze on "STATE OF AFFAIRS"
  ($edji & baby.murcielaga): user's screen recording showed MPD (rmpc) on
  that song while the bar kept "Robert Miles — Children", and Next clicks
  lagging. Root cause: mpd-mpris 0.4.4 (latest) rebuilds the current song on
  each change and re-downloads its embedded cover with `readpicture` in MPD's
  default 8 KB chunks (never sends `binarylimit`): that cover is a 3000×3000
  JPEG, 5.2 MB → 637 round trips, measured 7.5 s (1 MB chunks: 5 trips,
  0.06 s); meanwhile no track updates and queued commands. Fix: replace
  mpd-mpris with mpdris2-rs (AUR, reviewed: maintainer = upstream author,
  sha512-pinned v1.1.2 tag, cargo --locked, sandboxed user service), which
  sends `binarylimit 131072/524288` and is async. Our drop-in
  (systemd/.config/systemd/user/mpdris2-rs.service.d/override.conf, NO_FOLD):
  `--host 127.0.0.1:6600` (localhost → ::1 first, MPD is IPv4-only),
  `--no-notification`, `RuntimeDirectoryPreserve=yes` (its unit declares
  RuntimeDirectory=mpd, the same $XDG_RUNTIME_DIR/mpd that holds MPD's socket;
  without it a restart would delete MPD's socket folder). Covers now in
  $XDG_RUNTIME_DIR/mpd/album_art/. User installs + switches the services
  (ROOT-STEPS §16). Files: packages/{pacman,aur}.txt, system/ROOT-STEPS.md,
  install.sh, mpd/.config/mpd/mpd.conf, systemd/.config/systemd/user/
  mpdris2-rs.service.d/override.conf.

- **2026-11-22** — Media card backdrop decode 64×64 → 384×384 (user: more
  detail, still fast). ≈ the card width (380 px), so no detail lost; JPEG
  decodes directly at 1/8 scale, so big covers are never decoded full size;
  the blur's cost follows the item size, not the source. qs 1.4% of a core
  with the card open. Files: quickshell/.config/quickshell/popups/MediaCard.qml.

- **2026-11-22** — Now-playing card lagged / hung on some tracks (user:
  Robert Miles "Children" → "$edji & baby.murcielaga — STATE OF AFFAIRS").
  That album's cover is a 3000×3000 JPEG (5.2 MB, written by mpd-mpris to
  /tmp/mpd_mpris/artwork_*). The blurred backdrop Image had no sourceSize, so
  it decoded the full 9-megapixel image and FastBlur (radius 56) ran on it.
  Fix: backdrop sourceSize 64×64 (it's blurred anyway), FastBlur cached +
  radius 40; the cover thumbnail already decoded at 176×176. Tested on that
  track: card opens normally, qs 0.8% of a core while open, RSS unchanged.
  Files: quickshell/.config/quickshell/popups/MediaCard.qml.

- **2026-11-22** — Clicking a window in the overview didn't switch to it.
  activate() called Toplevel.activate() while the overview still held
  exclusive keyboard focus (close() only starts the fade), so Hyprland
  dropped the focus request. Now the action is stored (`pending`, a
  `hl.dsp.focus({ window = "address:…" })` dispatch, which also switches
  workspace; tile clicks the same with `{ workspace = N }`) and runs in the
  hide animation's ScriptAction once the overlay is gone. Tested via the same
  path (search + Enter): focus moved to the picked test window. Files:
  quickshell/.config/quickshell/overview/Overview.qml.

- **2026-11-22** — Overview shows ALL windows (user: a tiling WM has one or
  two windows per workspace, a per-workspace view loses the point). One grid
  of every window on workspaces 1-9, sorted by workspace then x/y
  (lastIpcObject.at), each with a workspace badge (tinted for the current
  one); keyboard selection starts on the active window. Workspace tiles: click
  = go there (no selection any more), drop target unchanged, the hovered /
  selected window's workspace lights up (`litWs`). Fix: a card filtered away
  while hovered left the highlight stuck → cleared on search change and card
  destruction. Files: quickshell/.config/quickshell/overview/Overview.qml,
  README.md. (This commit's first version of MAINTENANCE.md was garbled by a
  bad edit and restored in the next commit.)

- **2026-11-22** — README rewritten from scratch (user: the system changed a
  lot). New sections: The look, What's in it (by area), Install, Everyday use,
  generated Keybinds, Recovery (+ layout reset), Documentation (theme/README.md
  removed), Repository layout (makepkg/, qimgv/, overview/, docs/), Credits
  (Catppuccin dropped; conform.nvim, nvim-autopairs, rofi-calc, pix2tex, MPD,
  rmpc, qimgv, Claude Code Usage Monitor added). Screenshots retaken on
  workspace 2 with three demo windows (closed afterwards, user returned to
  workspace 1): desktop, compact, overview, stats, launcher, calc, wallpaper,
  powermenu (docs/screenshots/*.jpg, 1.9 MB). Files: README.md,
  docs/screenshots/.

- **2026-11-22** — Window overview (user: "gnome style swipe up to see all
  windows, tailored to this system"). quickshell overview/Overview.qml, one per
  monitor via Overlays (`overview` property + IPC toggle/open/close):
  search field (filters all windows), 9 workspace mini-maps (window rects from
  HyprlandToplevel.lastIpcObject at/size after Hyprland.refreshToplevels(),
  app icons, dot on the active one), the selected workspace's windows as live
  ScreencopyView thumbnails (captureSource = toplevel.wayland, only while
  open) in a grid sized for the biggest thumbnails; click = wayland.activate(),
  middle-click / ✕ = close(), drag onto a tile = `hl.dsp.window.move({
  workspace, window = "address:…", follow = false })` (follow=false = silent,
  from LuaBindingsDispatchers.cpp; without it the view follows), click tile =
  show it, double-click = go there, arrows/Enter, Esc. Triggers: ALT + A and
  hl.gesture 3 fingers up/down with a Lua function action (fires once at the
  end; directions per GestureTypes.hpp / LuaFunctionGesture.cpp). Tested with a
  test window + search (live thumbnail, strip mini-map); idle cost with it
  closed 0.1% of a core. During testing a non-silent move switched the user to
  workspace 9 (asked them to press ALT + 6). Also: icon fallback for unknown
  app ids; MediaCard loads cover art only while open (players delete old art
  files → "Cannot open" warnings). Files: quickshell/.config/quickshell/
  {overview/Overview.qml, services/Overlays.qml, shell.qml,
  popups/MediaCard.qml}, hypr/.config/hypr/conf/{input,keybinds}.lua,
  README.md.

- **2026-11-22** — Layout toggle made smooth (user). Bar: the layer surface no
  longer changes size (full width × 52, exclusionMode Normal, exclusiveZone
  52 spaced / 36 compact, `mask: Region { item: background }` so the empty
  margin is click-through; ignore_alpha keeps it unblurred); one animated
  `spaced` value (0..1, 320 ms OutQuint) drives the strip's x/y/width/height,
  radius and border alpha. Hyprland: layout-mode.sh applies the mode live with
  `hyprctl eval "hl.config(...)"` instead of `hyprctl reload`: gaps change
  once (windowsMove glides the tiles, 0.3 s), rounding steps 14 ↔ 0 in six
  50 ms steps (not animatable), shadows switch where least visible. ~0.36 s
  per switch; frame captures show the bar and windows moving gradually.
  Files: scripts/layout-mode.sh, quickshell/.config/quickshell/bar/Bar.qml.

- **2026-11-22** — Calculator, file finder, layout toggle (user request).
  ALT + = scripts/calc.sh: rofi-calc (libqalculate; package added, user
  installs), Enter copies the result. ALT + SHIFT + F scripts/find-file.sh:
  fd over $HOME (skips hidden, ~/GoogleDrive network mount, build dirs),
  newest first (~1.7k files, 0.02 s), Papirus icons by extension, Enter =
  xdg-open, Shift+Enter = Nautilus --select. Layout mode: one word in
  ~/.local/state/rice/layout (install.sh creates it), toggled by
  scripts/layout-mode.sh (bar button left of the coffee cup, ALT + G) which
  writes it and runs `hyprctl reload`; hypr/conf/look.lua reads it with io.open
  (compact = gaps 0, rounding 0, no shadows); services/LayoutMode.qml watches it
  (FileView watchChanges) and the bar becomes a square 36 px strip on the top
  edge (margins 0, no border), notifications move up to match. Verified:
  compact → bar 0,0 1920x36, tiled window at 2,38 (border only), rounding 0;
  spaced → bar 12,8 1896x44, rounding 14. Files: scripts/{calc,find-file,
  layout-mode}.sh, hypr/.config/hypr/conf/{keybinds,look}.lua,
  quickshell/.config/quickshell/{services/LayoutMode.qml, bar/LayoutIcon.qml,
  bar/Bar.qml, notifications/NotificationPopups.qml}, install.sh,
  packages/pacman.txt.

- **2026-11-22** — Bar music clicks swapped (user): left-click = play/pause
  again, middle-click = now-playing card; tooltip updated. Files:
  quickshell/.config/quickshell/bar/MediaModule.qml, MAINTENANCE §5.

- **2026-11-22** — Scroll-to-skip on the bar's music REMOVED (user): even with
  burst handling, fast irregular scrolling still let playback start (MPRIS
  Next always starts the track; the bar can only pause it again afterwards).
  Tooltip now "click: details · middle-click: play/pause". The skip-burst
  logic in Media.qml stays for the now-playing card's previous/next buttons.
  §5 decisions table updated. Files: quickshell/.config/quickshell/
  {bar/MediaModule.qml, services/Media.qml}.

- **2026-11-22** — Skip-while-paused still started playback when scrolling
  several notches (user). The first version re-read isPlaying on every skip;
  mid-burst it saw the auto-started track as "playing" and stopped re-pausing,
  and it re-paused only once. Now a burst of skips counts as one (state taken
  at the first skip, kept until 2.5 s after the last), pause() is sent right
  after each Next/Previous, and every isPlaying=true during the burst is
  paused again. Verified the D-Bus sequence on MPD: 3x (Next, Pause) →
  Paused on the 3rd track; 3x (Previous, Pause) → back, still Paused.
  Files: quickshell/.config/quickshell/services/Media.qml.

- **2026-11-22** — Skipping a paused track started playback (user wants it to
  stay paused). MPD (and most MPRIS players) start the new track on
  Next/Previous; MPRIS has no "skip, stay paused". services/Media.qml:
  next()/previous() go through skip(), which, if the player was paused, arms
  `keepPaused` for 2 s; when the player reports isPlaying it's paused again
  (a split-second blip of audio is possible). Covers bar scroll + the
  now-playing card buttons; media keys (playerctl in keybinds.lua) bypass it.
  Files: quickshell/.config/quickshell/services/Media.qml.

- **2026-11-22** — Scrolling on the bar's music did nothing although the
  tooltip promised "scroll: skip" (MPD reports CanGoNext/CanGoPrevious =
  true). MediaModule used a separate WheelHandler, which never got the wheel
  events; every icon that does scroll (audio, brightness, tray) uses the
  MouseArea's own onWheel + components/WheelSteps. Switched to that (down =
  next, up = previous). Can't inject a scroll here (no ydotool/wlrctl) →
  user-tested. Files: quickshell/.config/quickshell/bar/MediaModule.qml.

- **2026-11-22** — Fastfetch layout (item 11 of the visual tweaks): boxed
  "System" / "Hardware" sections (custom modules with box-drawing lines in
  blue, titles in bold ice), fastfetch's built-in Nerd Font icon per line via
  `{icon}` in the key, hand-padded key names (key.width is ignored for
  formatted keys), palette dots at the bottom. Widest line 57 columns incl.
  the logo, like before (half-width kitty re-wrap issue). Checked in a test
  kitty window. Files: fastfetch/.config/fastfetch/config.jsonc.

- **2026-11-22** — Now-playing card (item 6 of the visual tweaks): new
  popups/MediaCard.qml (PopupFrame "media"): blurred cover backdrop (FastBlur),
  cover, title / artist / album, player name, seek bar (Slider; only when
  canSeek + positionSupported; `position` written to seek) with times, shuffle
  / previous / play-pause / next / repeat (shuffle/repeat only if supported;
  repeat cycles off → all → track). MPRIS doesn't push position: a 1 s timer
  calls positionChanged() only while the card is open and playing. Bar: click
  the music = card, middle-click = play/pause, scroll = skip (tooltip says so).
  MediaModule gets `barWindow` from Bar.qml; the card is in a Loader until it's
  set (a PopupWindow needs a real window as anchor). Tested with MPD (rmpc):
  title/album/MPD/seek 0:58 of 2:08/controls correct; that track's extracted
  cover (/tmp/mpd_mpris/artwork_*) is a solid black 520×520 JPEG, so the cover
  shows black for it. Files: quickshell/.config/quickshell/{popups/MediaCard.qml,
  bar/MediaModule.qml, bar/Bar.qml}.

- **2026-11-22** — Step 4 of the visual-tweaks batch UNDONE (user): popups,
  notification popups, OSD, cheat sheet, stats panel and the workspace pill
  are back to plain Blue Ice (files restored from 82e5d63^; Theme.qml lost
  `cyan`, `edge`, `surfaceGradient`, `barGradient`). Steps 1, 2, 5 stay.
  Files: quickshell/.config/quickshell/{Theme.qml, popups/PopupFrame.qml,
  notifications/NotificationPopups.qml, osd/Osd.qml, cheatsheet/CheatSheet.qml,
  panel/StatsPanel.qml, bar/Workspaces.qml}.

- **2026-11-22** — Visual tweaks (user picked 1, 2, 4, 5, 6, 11 of my
  suggestions). 1: GTK accent-color 'teal' (install.sh gsettings; Nautilus
  keeps its scoped Nord accent). 2: Hyprland dim_inactive 0.07, `no_dim` on
  PiP + call pop-outs. 5: Papirus folders nordic → darkcyan (hue 186°, 45%
  sat, closest to the bar teal; ROOT-STEPS §11, user runs it). 4: the bar's
  palette in the shell: Theme.qml gains `cyan`, `edge` (teal-tinted border),
  `surfaceGradient` (steel blue top → surface glass) used by PopupFrame (all
  popups + notification center), cheat sheet and stats panel; `barGradient`
  (the bar's mirrored gradient) on the OSD pill; workspace pill cyan →
  lightBlue. Notification popups: tried the gradient, user asked to remove
  it → plain glass + edge. Files: install.sh, hypr/.config/hypr/conf/{look,
  rules}.lua, system/ROOT-STEPS.md, quickshell/.config/quickshell/{Theme.qml,
  popups/PopupFrame.qml, notifications/NotificationPopups.qml, osd/Osd.qml,
  cheatsheet/CheatSheet.qml, panel/StatsPanel.qml, bar/Workspaces.qml}.

- **2026-11-22** — Bar gradient: centre looked "goofy", too dark (navy at 13%
  lightness vs 18-23% elsewhere). Equal HSL lightness wasn't enough (blue
  looks darker than teal: rel. luminance still 0.043 → 0.023), so the colours
  are now picked in OKLCH at equal perceived lightness: L 0.335, C ~0.06,
  hue 215 → 248 → 270 → barEdge #003e4a, barMid #1a3955, barCentre #2a3458,
  all @0.93. Measured luminance 0.033-0.034 across the whole bar, symmetric;
  white 11.7:1+, muted 5.8:1+. Tip for future colour work: balance in OKLCH,
  not HSL. Files: quickshell/.config/quickshell/Theme.qml.

- **2026-11-22** — Bar gradient redesigned, pink/lavender dropped (user:
  "choose the colors yourself … make something good"). "Deep glacier",
  mirrored: barEdge #12424f@0.93 (deep teal) → barMid #1f3a61@0.92 (steel
  blue, 26% / 74%) → barCentre #141d30@0.90 (navy). Measured: hue 193 → 215
  → 224°, sat 64 → 53 → 42%, lightness 18-23% (centre 13%), both halves
  identical; white text 11-16:1, Theme.muted 5.5:1, so barMuted was removed
  and the date / empty workspaces use Theme.muted again. Files:
  quickshell/.config/quickshell/{Theme.qml,bar/Bar.qml,bar/Clock.qml,
  bar/Workspaces.qml}.

- **2026-11-22** — Bar gradient more vivid (user: "too washed out"): barRose
  #802e70@0.95, barLavender #4d409e@0.93, centre navy @0.85 (measured ends
  #772C6B, quarters #463A91, symmetric). White text 8.4:1; Theme.muted fell
  to 4.1-4.3:1 there, so the bar uses new Theme.barMuted (muted + 40% ice,
  5.2-5.4:1) for the date and empty workspace numerals. Files:
  quickshell/.config/quickshell/{Theme.qml,bar/Clock.qml,bar/Workspaces.qml}.

- **2026-11-22** — Bar gradient redone (user: the pastel version "just looks
  like a white blur", wanted tasteful + symmetric). Pastel tints at 50% over
  the translucent glass washed out under the blur. Now deep, mostly opaque
  tones, mirrored: barRose #66385f@0.88 (ends) → barLavender #403b73@0.85
  (24% / 76%) → Blue Ice navy @0.82 (centre). Measured left/right ends
  #5A3155/#593155; white text ≥ 9.8:1, muted ≥ 4.9:1, so the clock's date is
  back to Theme.muted. Theme.qml: barRose/barLavender/barCentre replace the
  pastel lavender/pink. Files: quickshell/.config/quickshell/{Theme.qml,
  bar/Bar.qml,bar/Clock.qml}.

- **2026-11-22** — Bar background gradient (user: lavender · current colour ·
  pastel pink): horizontal gradient, lavender tint (left) → Theme.glass
  (middle) → pastel pink #f5bde6 tint (right), ends = Qt.tint(glass, colour
  @ 0.5) so it stays dark glass. Measured: left #5C5989, right #75617D; white
  text ≥ 5.2:1 everywhere. The clock's date was Theme.muted = 2.6:1 on the
  pink end → now an ice/text mix (4.7:1). Theme.qml gained `lavender` and
  `pink`. Files: quickshell/.config/quickshell/{Theme.qml,bar/Bar.qml,
  bar/Clock.qml}.

- **2026-11-22** — Subtle Blue Ice "aurora" window border (user: noticeable
  sometimes, not distracting). Active: 5-stop gradient lightblue(ee) → ice(d9)
  → cyan(d9) → lavender(b3) → lightblue(ee) at 45° (cyan/lavender = kitty's
  ANSI cyan/magenta, added to colors.lua); inactive: overlay(cc) → blue(80).
  borderangle stays `once` but slower (8 → 14 = 1.4 s sweep on focus change),
  border colour fade 2.0 → 2.5; no loop, so no constant redraws. Verified by
  sampling a test window's border: light blue → ice (top) → cyan (right) →
  lavender (bottom) → light blue. Files: hypr/.config/hypr/conf/{colors,look,
  animations}.lua.

- **2026-11-22** — Theme generator removed (user: "I never really use
  anything other than blue ice"). Deleted theme/ (render.sh, apply.sh,
  4 palettes, style.toml, 17 templates, README), scripts/theme-picker.sh +
  ALT + T bind, scripts/fastfetch-logo.sh (unused, read the palettes). The 17
  former outputs stay as plain Blue Ice files; only their "GENERATED / edit
  the template" headers changed (verified with git diff). Kept + moved:
  theme/qt.sh → scripts/qt-config.sh (qt*ct.conf needs an absolute path),
  theme/qimgv.sh → scripts/qimgv-theme.sh (qimgv rewrites its file).
  install.sh: no `render` step; `qt` step calls the moved helpers. Docs:
  README, MAINTENANCE §2/§3/§4/§5/§8, APPS.md, GAMING.md, comments. Restore
  the switcher: `git checkout 4b4f8c6 -- theme scripts/theme-picker.sh` (+ the
  ALT+T bind). Files: as above.

- **2026-11-22** — Full compatibility check of recent changes (user request).
  OK: Hyprland verify/configerrors, no duplicate binds, workspaces 1-9; no
  failed system/user units; no broken stow links; all listed packages
  installed; every tracked .sh (bash -n), .py and .lua parses; theme render
  idempotent; README keybind table current; no secrets/home paths; nvim
  plugins at the locked commits; clang-format / latexindent (4 spaces, no
  indent.log) / rustfmt / ruff work; ccmonitor statusline live; LaTeX OCR
  venv imports; default apps right; no .pacnew; fwupd clean. Fixed: Quickshell
  ReferenceError "card is not defined" (NotificationPopups.qml:203): an
  action button's invoke() makes many apps close the notification, which
  destroys the card mid-handler; now takes `card.n` first. Listed
  python-pandas (user, 2026-11-20). Orphans left for the user: cmake, meson
  (qimgv/euphonica build deps), gspell, libgedit-tepl, libpeas (from gedit).
  Files: quickshell/.config/quickshell/notifications/NotificationPopups.qml,
  packages/pacman.txt.

- **2026-11-22** — Workspaces 6 → 9 (user request): ALT + 1…9 / ALT + SHIFT +
  1…9 (keybinds.lua), persistent 1-9 (rules.lua), bar shows 一…九 with the
  pill limit following the list (bar/Workspaces.qml). README table
  regenerated. Files: hypr/.config/hypr/conf/{keybinds,rules}.lua,
  quickshell/.config/quickshell/bar/{Workspaces,Bar}.qml, README.md.

- **2026-11-21** — OPEN (user: "later"): battery lasts ~1 h browsing →
  ~50 W draw from 52.7 Wh, not a dead battery. Suspects: platform_profile
  pinned to performance also on battery (system/units/platform-profile-
  performance.service + 99-platform-profile.rules), RTX 3050 awake (RTD3 bug,
  ~3 W + memory/link), 144 Hz. Plan: user unplugs ~3 min, read
  /sys/class/power_supply/BAT0/power_now (µW); then temporary
  `echo balanced | sudo tee /sys/firmware/acpi/platform_profile` (re-pinned on
  replug) and measure again. If big: ASK user to switch "full tilt always" to
  performance on AC / balanced on battery (their explicit choice; don't change
  without a yes).

- **2026-11-21** — Battery health baseline (user asked; no change made):
  BAT0 (HP "Primary", Li-ion) energy_full 52.65 Wh / energy_full_design
  70.07 Wh = 75.1%, cycle_count 49 (`/sys/class/power_supply/BAT0`, same as
  `upower -i`). These come from the battery's gauge chip (lifetime values,
  not reset by reinstalling the OS). Laptop is 3-4 years old and mostly on
  AC → few cycles; 75% is normal calendar ageing for that (sitting at 100%,
  warm), not abnormal wear. No charge_control_end_threshold in sysfs on
  this model; advised: one full calibration cycle, HP BIOS "Adaptive Battery
  Optimizer", HP F2 Battery Test if under warranty. Recheck these numbers
  later to see the trend.

- **2026-11-21** — Stats panel v2 trimmed (user): removed the sparklines
  behind the Frequency / Temperature / Load tiles (and their histories) and
  the "All systems normal" health pill (+ the health summary). Load tile now
  says what it is: "Load avg (1 min)", sub "5m … 15m …", value turns warn
  colour above the thread count. Thermometer under Temperature kept. Files:
  quickshell/.config/quickshell/panel/StatsPanel.qml.

- **2026-11-21** — Stats panel v2 (user: v1 = tag `stats-panel-v1`, then "add
  all kinds of bells and whistles"). Added: greeting, live clock with seconds
  + seconds line, static soft glows, health pill (most serious issue first,
  pulses only on warn/critical), rings with ticks, count-up and alert pulse,
  sparklines behind the CPU tiles + thermometer, hover a thread → its own
  60 s graph, network peaks + pulsing arrows while traffic flows, charging
  shimmer, process app icons (DesktopEntries, cached) / letter badges,
  collapsible sections saved in `~/.local/state/quickshell/by-shell/<id>/
  stats-panel.json`, card hover glow, skeleton placeholders, "Live" footer.
  Performance (CPU of qs with the panel open, 15-20 s average): first v2
  69%, v1 62%; after fixes 29%, closed 0%. Fixes: graphs build their curve
  once per value and slide it with a Translate (no per-frame path rebuild),
  eased 0.45 s slide instead of a continuous glide, no looping animations
  while all is normal (they force 144 Hz redraws), no tween on the seconds
  line, icon lookups cached. Incident: a multi-file install wedged the hot
  reload; my restart used `hyprctl dispatch exec qs`, which fails in Lua mode
  (output was silenced), so the bar was down ~2 min until restarted with
  `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`. Files:
  quickshell/.config/quickshell/panel/StatsPanel.qml,
  components/{RingGauge,Graph}.qml.

- **2026-11-21** — Stats panel graphs glide instead of jumping every poll:
  Graph.qml animates a horizontal `shift` (one step -> 0 over `glide` =
  SystemStats.interval, linear) so each new point slides in from the right
  and the oldest slides out on the left (step = width / (capacity - 2), so
  it rests just off-screen; curves clipped). The dot follows the curve at
  the right edge (interpolated), `max` changes ease (vmax, 700 ms).
  Verified: three frames 0.4 s apart within one poll all differ, the line
  moving left a few px each frame. Files: components/Graph.qml,
  panel/StatsPanel.qml (glide bound to the poll interval).

- **2026-11-21** — Stats panel: per-core bars → per-thread heat map (2 rows,
  tile brightness = load, warn/critical tones, exact % + T<n> label; footer
  names the busiest thread). Panel opened scrolled down: the PanelWindow
  persists between opens, so the Flickable kept its old contentY; show() now
  resets it to 0. (A property named `top` on a StyledText failed to load:
  "Cannot override FINAL property", it's the anchor line; renamed.) Files:
  quickshell/.config/quickshell/panel/StatsPanel.qml.

- **2026-11-21** — Stats panel (ALT + S) redesign (user: "looks kinda basic").
  Same data, polling and behaviour (Esc/outside click, kill confirm, frozen
  process rows); new look: gradient hero (clock, date, host/uptime/kernel
  chips, Arch watermark), overview row of four gradient rings (CPU, RAM,
  GPU, root disk), section headers with icon chip + key number, stat tiles,
  gradient bars, taller per-core bars, process rows with usage bars + rank,
  sliding CPU/Memory switch, cards fade/rise in staggered (45 ms each).
  components/RingGauge.qml: gradient arc (ShapePath.strokeGradient) + glow,
  `color2`, `labelSize`; components/Graph.qml: Catmull-Rom curve (PathSvg),
  glow, dot on the newest value, dotted baseline until history fills (only
  the stats panel uses either). Gotchas hit: a failed hot reload (Behavior on
  a readonly property) left the running qs failing every later reload with
  "<inline component> is not a type"; verified in a separate `qs -p <copy>`
  instance, then restarted qs (qs kill + `hyprctl dispatch exec qs`). The
  Arch glyph U+F303 had to be inserted by code point. Files:
  quickshell/.config/quickshell/panel/StatsPanel.qml,
  components/{RingGauge,Graph}.qml.

- **2026-11-21** — zathura `:open` Tab completion ran off the visible area
  with many entries. zathura 2026.10.23 (completion UI now in zathura's
  girara-gtk/completion.c) puts the rows in a GtkScrolledWindow with
  `max_content_height` 300 px that doesn't scroll to the selection, and shows
  n-completion-items + 1 rows + the group header. Our 20 (~486 px) overflowed.
  Fix: n-completion-items 10 (~266 px at JetBrainsMono 11). Files:
  zathura/.config/zathura/zathurarc.

- **2026-11-19** — ccmonitor shows official, account-wide limits (incl.
  Claude desktop chats, which share the plan limits but leave no local logs):
  user set `"statusLine": {"type": "command", "command":
  "~/.local/bin/ccmonitor --statusline"}` in ~/.claude/settings.json (not in
  the repo; re-add on a new machine). Claude Code pipes `rate_limits` to it;
  ccmonitor stores them in ~/.claude-monitor/statusline/latest.json, no
  network. Verified: `confidence=official`, five_hour 7% (local estimate was
  ~1%). seven_day comes back null (Claude Code didn't send one). Stale after
  10 min without a Claude Code session. Files: zsh/SHELL-CHEATSHEET.md.

- **2026-11-19** — No more `-debug` AUR packages (user request). New stow
  package `makepkg` → `~/.config/pacman/makepkg.conf` (makepkg reads it after
  /etc/makepkg.conf): `OPTIONS=("${OPTIONS[@]/#debug/!debug}")`. Verified with
  makepkg's own `source_makepkg_config`: `... purge !debug lto`. Existing
  euphonica-debug, qimgv-debug, yay-debug: user removes them with pacman -Rns.
  Files: makepkg/.config/pacman/makepkg.conf, install.sh (STOW_PACKAGES).

- **2026-11-19** — Package lists synced with the system (`pacman -Qqe` vs
  packages/*.txt; xorg-* is covered by base.txt's glob). Added python-mutagen
  (user, 2026-11-14; yt-dlp tags/cover art), gtk4-layer-shell (user,
  2026-11-11; unused by the repo) and `yay` itself to aur.txt; ROOT-STEPS §5.0
  now bootstraps `yay` (source build, what's installed) instead of `yay-bin`,
  which would conflict with the listed `yay`. Not listed on purpose:
  *-debug split packages (euphonica/qimgv/yay-debug, built because
  /etc/makepkg.conf has `debug` in OPTIONS) and protonup-qt's AUR deps
  (python-steam, python-inputs; installed as dependencies, noted in aur.txt).
  Files: packages/pacman.txt, packages/aur.txt, system/ROOT-STEPS.md.

- **2026-11-18** — Added `7zip` (official, replaces p7zip) to packages/pacman.txt.
  Before: .7z opened only through libarchive (bsdtar, File Roller), which
  can't decrypt password-protected archives or create .7z, and the zsh
  `extract` plugin failed on .7z (calls `7za`). Files: packages/pacman.txt.

- **2026-11-18** — `ccmonitor` (Claude Code Usage Monitor, PyPI
  claude-monitor 4.0.0, MIT; user request). Not in the repos; the only AUR
  package (claude-monitor-git) is a 2025 snapshot with 0 votes, so it gets a
  private venv like LaTeX OCR: `scripts/ccmonitor/setup.sh` (user runs it)
  installs `requirements.txt` (16 wheels, SHA-256 pinned) into
  `~/.local/share/ccmonitor/venv`; `bin/.local/bin/ccmonitor` runs it.
  Source reviewed: reads ~/.claude/projects/*.jsonl, writes ~/.claude-monitor/;
  no network unless `--api` (then it sends the Claude OAuth token from
  ~/.claude/.credentials.json to api.anthropic.com/api/oauth/usage);
  subprocess calls are macOS/Windows-only. Update: see the comment at the top
  of requirements.txt. Files: scripts/ccmonitor/{setup.sh,requirements.txt},
  bin/.local/bin/ccmonitor, README.md, zsh/SHELL-CHEATSHEET.md.

- **2026-11-17** — Neovim formatting for C/C++, LaTeX, Rust, Python (user
  request): conform.nvim (pinned 016802d; source skimmed: runs local formatter
  binaries only). `Space c f` (Normal = file, Visual = selection) replaces the
  LSP-only binding, so it also works without a language server (no clangd).
  clang-format: project `.clang-format` if any, else LLVM + IndentWidth 4;
  latexindent: `-g /dev/null` (no indent.log) and 4-space defaultIndent (its
  default is tabs); rustfmt (format on save, replaces the old BufWritePre
  LSP hook in lsp.lua); ruff format. latexindent was broken (missing Perl
  YAML::Tiny, File::HomeDir) → packages perl-yaml-tiny, perl-file-homedir,
  ruff added; clang listed explicitly (was only a dependency of bcc).
  Files: nvim/.config/nvim/lua/plugins/{format,lsp}.lua, lazy-lock.json,
  packages/pacman.txt, nvim/CHEATSHEET.md.

- **2026-11-17** — LaTeX OCR background mode (user request): ~9 s per capture
  was almost all PyTorch + model loading. `latex_ocr.py --serve` keeps the
  model loaded and answers on `$XDG_RUNTIME_DIR/latex-ocr.sock` (mode 0600;
  one line = image path in, JSON out). `latex-ocr.sh` runs `--warm` when the
  key is pressed (loads while you select) and `--ask IMG` after; "Reading…"
  notification only if the answer takes > 0.6 s. Exits after 20 min idle
  (`LATEX_OCR_IDLE` seconds), `--stop` stops it; a flock on
  `latex-ocr.lock` keeps it to one server. Measured: cold ~10 s, warm
  ~0.9 s, ~750 MB RSS while running; bad images return an error without
  killing it. Log: `$XDG_RUNTIME_DIR/latex-ocr.log`. Files:
  scripts/latex-ocr/latex_ocr.py, scripts/latex-ocr.sh.

- **2026-11-17** — LaTeX OCR gave gibberish (endless `\qquad`) on a clean
  equation. The model was fine (the same PNG read perfectly from file); the
  screen selection included a dark viewer frame around the light picture.
  pix2tex's own `pad()` picks "text" by brightness and then read the whole
  light picture as one glyph. Fix: `clean()` in latex_ocr.py splits pixels
  with Otsu, tries both polarities, drops blobs touching the selection edge or
  shaped like a frame, keeps the polarity with the most glyph-sized blobs, and
  crops the ORIGINAL pixels to them (dark on white, background levelled; an
  earlier version that masked to the blobs lost i/j dots and broke `=`).
  Tested: plain, dark frame, inverted, inverted + frame, 1.8x zoom + frame all
  give the exact LaTeX. `LATEX_OCR_DEBUG=/path.png` saves what the model sees.
  Files: scripts/latex-ocr/latex_ocr.py.

- **2026-11-17** — LaTeX OCR (user request): ALT + SHIFT + O selects a region
  and copies it as LaTeX, using pix2tex 0.1.4 (lukas-blecher/LaTeX-OCR, MIT)
  in a private venv `~/.local/share/latex-ocr/venv` (not in the repo, not
  system-wide). `scripts/latex-ocr/setup.sh` (user runs it) installs
  `requirements.txt`: 46 wheels, each pinned by SHA-256 (`--require-hashes`,
  `--only-binary`, `--no-deps`), CPU-only torch 2.15.0+cpu from
  download.pytorch.org, plus pins transformers<5 / opencv<5 (pix2tex predates
  their 5.x). It downloads the two model files from the pix2tex v0.0.1 release
  itself and checks their SHA-256 (pix2tex's own downloader doesn't).
  `latex_ocr.py` wraps `pix2tex.cli.LatexOCR`, keeps stdout for the result and
  disables pix2tex's own clipboard copy. Source read, not run by Claude (the
  resolve was a `pip --dry-run`). **To update:** in a scratch venv run
  `pip install --dry-run --only-binary=:all: --ignore-installed --report r.json
  --index-url https://download.pytorch.org/whl/cpu --extra-index-url
  https://pypi.org/simple pix2tex==0.1.4 "transformers<5" "opencv-python-headless<5"`,
  regenerate requirements.txt from r.json (name==version + sha256), re-run
  setup.sh. Remove: `rm -rf ~/.local/share/latex-ocr`. Files:
  scripts/latex-ocr.sh, scripts/latex-ocr/{setup.sh,latex_ocr.py,requirements.txt},
  hypr/.config/hypr/conf/keybinds.lua, README.md.

- **2026-11-17** — Neovim: auto-closing brackets and `$…$` (user request, "not
  annoying"). Added `windwp/nvim-autopairs` (lua/plugins/autopairs.lua, pinned
  in lazy-lock.json at 3172f40, source read: pure Lua, no build step, no network).
  Defaults keep it quiet (no pair before a word, step over closers, Backspace
  deletes pairs, Enter between brackets indents); no fast-wrap (ALT + e is
  Hyprland's). Custom `$` rule for tex/plaintex/markdown pairs only after a
  space / line start / `( [ {` and not before a word or `$`; `` ` `` and `'`
  not paired in tex. Enter still accepts blink.cmp completions: blink's
  buffer-local `<CR>` falls back to autopairs' global one when the menu is
  closed. Not run by Claude (third-party code): installed by lazy.nvim on the
  next Neovim start. Files: nvim/.config/nvim/lua/plugins/autopairs.lua,
  lazy-lock.json, nvim/CHEATSHEET.md, README.md.

- **2026-11-16** — Brightness keys "stop at 95%, down is glitchy". The keys
  and brightnessctl were fine: a backlight log showed clean 5% steps up to
  96000/96000 (100%). The OSD lagged one step behind: its handler ran on
  `Brightness.currentChanged` and read the derived `Brightness.value`
  (current / max), which wasn't re-evaluated yet, so it showed the previous
  level (95% at full, one step too high going down) and stayed there when the
  next press changed nothing. Fix: handle `onValueChanged` instead. Verified
  with screenshots: 85→100 shows 100%, four steps down shows 80%.
  Same day: notification center empty state (bell + "No notifications") sat
  at the left; a nested ColumnLayout only stretches if a child fills the
  width, so both children now fill it and center their text.
  Files: `quickshell/.config/quickshell/osd/Osd.qml`,
  `quickshell/.config/quickshell/notifications/NotificationCenter.qml`.

- **2026-11-16** — qimgv themed + "View All Images" (user request).
  Colors: new template `theme/templates/qimgv/theme.conf.tmpl` → `qimgv/theme.conf`
  (not a stow package). qimgv rewrites `~/.config/qimgv/theme.conf` on every
  exit, so `theme/qimgv.sh` copies it there instead (strips `#` comments, sets
  `useSystemColorScheme=false`); run by install.sh step `qt` and theme/apply.sh,
  skipped while qimgv is open (it would overwrite the file on close). Recursive
  view: qimgv has no recursive mode in the UI (`setDirectoryRecursive` is only
  used by `--gen-thumbs`), so `scripts/view-all-images.sh` (+ `view-all-images`
  in ~/.local/bin, Nautilus extension `view_all_images.py`) builds a flat folder
  of symlinks named `Sub › Dir › file.jpg` under
  `$XDG_RUNTIME_DIR/view-all-images/<hash>/` and opens it. Tested on ~/Pictures
  (grid + colors correct). Files: those plus install.sh, theme/apply.sh,
  README.md, zsh/SHELL-CHEATSHEET.md.

- **2026-11-16** — Image viewer: default switched from Loupe to **qimgv** (user
  request: wanted a more featureful viewer). qimgv is AUR only (PKGBUILD
  reviewed at 7c5bb4e: upstream tag tarball, cmake, no .install); the AUR build
  has no EXIF panel or video playback. Added `qt6-imageformats` + `kimageformats`
  so it opens TIFF/AVIF/HEIC/JXL too. Loupe stays installed as a fallback
  (Open With). qimgv's own settings (`~/.config/qimgv/`) are not stowed: it
  rewrites that file itself. Files: `xdg/.config/hyprland-mimeapps.list`,
  `packages/pacman.txt`, `packages/aur.txt`.

- **2026-11-15** — rmpc search found nothing for a song that was in ~/Music:
  MPD knew 112 of 255 files. The other 143 were copied in at 23:15:11 on
  11-14, the same second MPD's first scan finished (its inotify watches start
  after that scan), so they were never added. `rmpc update` added all 143;
  auto_update verified afterwards (temporary test file picked up and removed
  within seconds). If a song is "missing" in rmpc/Euphonica: compare
  `find ~/Music -type f | wc -l` with MPD `stats`, then `rmpc update`. No
  config change.

- **2026-11-15** — RTD3 re-probe workaround removed again: the user prefers to
  wait for NVIDIA's official fix (files deleted, ROOT-STEPS §17 dropped). The
  RTX 3050 stays awake (~4 W) meanwhile; tracked in §6. If ever needed: the
  workaround script is in issue #1507 (william8000, 2026-11-15) and in git
  history (commit ad6b862).

- **2026-11-15** — RTX 3050 awake all the time since the 2026-11-13 upgrade
  (kernel 7.2.15 → 7.3.4, nvidia-open 615 → 620.70). `/proc/driver/nvidia/gpus/
  0000:01:00.0/power`: "Runtime D3 status: Disabled by default";
  `power/control` = on, runtime_status active. Cause: Linux 7.3 runs kthreads
  in a nullfs root, so the driver's probe kthread can't open the GPU's PCI
  config → RTD3 silently off (NVIDIA bug 7039712, GitHub issue #1507, fix PR
  #1512 not released). Workaround (user runs ROOT-STEPS §17,
  root-steps/6-nvidia-rtd3.sh): oneshot `nvidia-rtd3-rebind.service` before
  display-manager: rmmod nvidia_drm/modeset/uvm, unbind/bind the GPU, modprobe
  again; no-op when RTD3 already reports enabled. Remove it once a driver /
  kernel with the fix is installed. The i915 `intel_pps_vdd_on_unlocked`
  WARNING at boot is unrelated (panel power sequencing). Files:
  system/usr-local-sbin/nvidia-rtd3-rebind, system/units/…service,
  system/root-steps/6-nvidia-rtd3.sh, ROOT-STEPS §17.
- **2026-11-15** — Euphonica verified: connected to MPD at 127.0.0.1:6600,
  own server off, MPRIS off (only `mpd` in playerctl), online providers off.

- **2026-11-15** — Plattenalbum dropped (its cover grid is per artist; the
  library is mostly singles). Replaced by **Euphonica** (AUR [d33c282]
  reviewed: Album View = whole-library cover grid). Defaults checked in its
  gschema: own MPD server off, online metadata providers off, MPRIS on →
  install.sh sets enable-mpris false and mpd-host 127.0.0.1 (localhost → ::1
  first; MPD binds IPv4). Kept from the Plattenalbum attempt: MPD's runtime
  socket + RuntimeDirectory drop-in (useful for any local client). Files:
  packages/aur.txt, install.sh, ROOT-STEPS §16, mpd.conf comment.

- **2026-11-15** — Plattenalbum said "set up MPD": without MPD_HOST it only
  tries the sockets `$XDG_RUNTIME_DIR/mpd/socket` and `/run/mpd/socket`, and
  MPD listened on 127.0.0.1:6600 only (an explicit bind_to_address disables
  MPD's default runtime socket). Fix: second `bind_to_address
  "$XDG_RUNTIME_DIR/mpd/socket"`. Two traps on the way (MPD was down ~2 min):
  (1) MPD doesn't create that folder for a configured path → drop-in
  `mpd.service.d/runtime-dir.conf` with `RuntimeDirectory=mpd`; (2) stow folded
  `mpd.service.d` into a symlink to the repo and systemd ignored it ("changed
  on disk" forever) → listed in install.sh NO_FOLD_DIRS so it's a real folder
  with the file linked inside. Rule: systemd *.d drop-in folders must be real
  folders. Files: mpd.conf, systemd/.config/systemd/user/mpd.service.d/,
  install.sh, ROOT-STEPS §16.

- **2026-11-15** — Plattenalbum (GTK4/libadwaita MPD client with an album-cover
  grid; rmpc has no thumbnail view): AUR package reviewed [6638db1] and listed.
  Its built-in MPRIS (gsettings key `mpris`, default true) duplicated MPD next
  to mpd-mpris → install.sh step gsettings sets it false. Follows the dark
  libadwaita style / gtk-4.0 css. Files: packages/aur.txt, install.sh,
  ROOT-STEPS §16.

- **2026-11-14** — rmpc didn't launch from rofi (kitty window closed ~1 s after
  rmpc started; rmpc's log just stops, no crash recorded). The same command run
  from a shell worked. Cause: the Exec line carried escaped inner quotes
  (`font_family=family=\"JetBrainsMono Nerd Font\" style=Medium`); .desktop
  Exec values go through key-file unescaping *and* shell-style quoting, and
  `\"` isn't a valid key-file escape, so launchers can split it differently.
  Fix: no inner quotes, kitty's full-name form
  `-o "font_family=JetBrainsMono Nerd Font Medium"` (verified: kitty
  load_config parses it; GLib KeyFile + shell_parse_argv give clean argv).
  Rule: never put `\"` in a .desktop Exec. File: rmpc.desktop.

- **2026-11-14** — rmpc text colours + font from a reference screenshot (user
  request): Catppuccin Mocha accents, fixed hex in rice.ron.tmpl — artist /
  default text subtext1 #bac2de, titles sapphire #74c7ec, playing song mauve
  #cba6f7 bold, selection + active tab lavender #b4befe on #1e1e2e, [Playing]
  / volume / scrollbar lavender, header artist rosewater #f5e0dc, separators
  overlay2 #9399b2, secondary subtext0 #a6adc8. Font: the reference is
  JetBrains Mono (Medium): launcher passes kitty
  `-o "font_family=family=\"JetBrainsMono Nerd Font\" style=Medium"` and
  `foreground=#cdd6f4` (font spec parsed with kitty's load_config). Borders,
  background, cava unchanged. Files: rice.ron.tmpl, rmpc.desktop.

- **2026-11-14** — rmpc themes catppuccin-pink and nuclear-light deleted (user
  request); only `rice` remains. config.ron / rmpc.desktop comments trimmed.

- **2026-11-14** — rmpc back to the `rice` theme (user request); launcher
  background #202636 again. catppuccin-pink and nuclear-light stay in
  rmpc/.config/rmpc/themes/ (config.ron lists how to pick them).

- **2026-11-14** — nuclear-light: much text was near-white on the pink
  background. Cause: rmpc's `text_color` doesn't reach song-table columns, tab
  labels, list symbols, header title / elapsed fields; unstyled text uses the
  terminal default (kitty foreground #f4f8ff), and "Dim" styles get lighter.
  Fix: explicit fg everywhere (black text, #674d53 labels / inactive tabs /
  elapsed, Dim replaced by the muted colour) + the launcher sets kitty
  `foreground=#000000`. Lesson for light rmpc themes: style every Property.
  Files: nuclear-light.ron, rmpc.desktop.

- **2026-11-14** — rmpc theme `nuclear-light` (user request), now active: the
  Nuclear player's light palette from its packages/tailwind-config/global.css
  (:root, OKLCH → hex): background #fadadf, primary #ff9cb4 (selected row,
  active tab), black text + borders; deeper same-hue shades for coloured text
  (#bd3964 highlights/progress, #6d41a9 state/artist); white progress track;
  cava #ff4e6c → #a87eeb → #549de5; text_color set (kitty's light default
  text would vanish on pink). Launcher background #fadadf; config.ron lists
  all three themes with their launcher colours. File:
  `rmpc/.config/rmpc/themes/nuclear-light.ron`.

- **2026-11-14** — rmpc theme `catppuccin-pink` (user request), now active:
  same layout, made from rice.ron.tmpl with Catppuccin Macchiato colours
  (pink #f5bde6 accent/borders/progress, mauve #c6a0f6 for state/artist,
  base #24273a solid background, cava mauve → pink → rosewater). Static file
  (not rendered by render.sh); regenerate from the template after layout
  changes. Launcher background #24273a to match; `theme: Some("rice")` +
  #202636 switches back. Files: `rmpc/.config/rmpc/themes/catppuccin-pink.ron`,
  config.ron, rmpc.desktop.

- **2026-11-14** — rmpc opaque like the reference (user request): theme
  background / header / modal colour #202636 (sampled from the screenshot;
  fixed, not palette) — kitty's background_opacity only affects the default
  background, so these cells are solid; launcher runs kitty with
  `-o background_opacity=1 -o "background=#202636"` so the padding matches
  (`#` must be quoted in .desktop Exec). Files: rice.ron.tmpl,
  `applications/.../rmpc.desktop`.

- **2026-11-14** — More fonts (user picked: full language coverage, popular
  UI/document fonts, Microsoft-compatible): 16 official packages added to
  pacman.txt (~550 MB). UI fonts stay as set (gsettings / Theme.qml), so
  nothing changes look by itself.

- **2026-11-14** — Tauon Music Box removed again (user request): out of
  pacman.txt and the README; user uninstalls (`pacman -Rns` also drops its
  ~25 Python/lib deps, incl. python-mutagen, which only rmpc's optional
  YouTube feature would use). It left no data folders behind.

- **2026-11-14** — rmpc restyled after a reference screenshot (user request):
  Queue tab = album art 38% | queue (40%) over a big Cava pane; lyrics pane
  dropped. Theme: tabs in their own box; bottom = one box with ▶/⏸/■
  (StateV2 labels) + thick rounded progress bar (symbols e0b6 █ e0b4 █ e0b4,
  overlay track) + elapsed / duration; input-mode box removed; rmpc's original
  "yellow" (state, artist, toggles, preview labels) → palette warn (gold).
  Cava: bar_width 2 / spacing 1, fixed gradient #ff3d8b → #b07cff → #3fc5ff
  (doesn't follow ALT+T). Hidden-pty run: no new warnings (dup-key warnings
  come from rmpc's example keybinds). Files: `rmpc/.config/rmpc/config.ron`,
  theme template rice.ron.tmpl.

- **2026-11-14** — rmpc gets cava (user request): rmpc 0.11's built-in Cava
  pane (src/ui/panes/cava.rs), 9 rows under the album art in the Queue tab.
  config.ron `cava: (...)`: 60 fps, autosens, input PipeWire "auto" (whatever
  is playing). Theme template `cava: (...)`: bars from the bottom, gradient
  blue → lightblue → ice (follows ALT+T). rmpc writes /tmp/rmpc/cava-<uid>.conf
  and runs `cava -p` only while the pane is on screen. Checked in a hidden pty:
  config/theme accepted, cava started, no errors. (Killing rmpc with a signal
  can orphan its cava; quitting with q is fine.)

- **2026-11-14** — rmpc + MPD verified after install: mpd + mpd-mpris user
  services active/enabled; 112 songs indexed; PipeWire output; `rmpc debuginfo`
  reads config.ron + themes/rice.ron and connects (MPD 0.24); the bar shows MPD
  (MPRIS identity is already "MPD", so no name mapping). First-start "Failed to
  open …/database / …/state" in the journal is normal (files created after).
  Album art: rmpc resolves the kitty protocol only inside a real kitty window.

- **2026-11-14** — rmpc + MPD (user request; all official packages: mpd,
  rmpc 0.11.0, mpd-mpris). New stow packages `mpd/` (mpd.conf: ~/Music,
  ~/.local/share/mpd + ~/.local/state/mpd, 127.0.0.1:6600, PipeWire,
  restore_paused) and `rmpc/` (config.ron = rmpc 0.11.0 example with
  theme "rice" + cache dir; BSD-3 notice kept). Theme template
  `theme/templates/rmpc/.config/rmpc/themes/rice.ron.tmpl` = the example theme
  with named colours mapped to the palette (render.sh → rmpc/.../themes/rice.ron).
  `applications/rmpc.desktop` runs it in kitty (class rmpc, icon mpd).
  install.sh: dirs + stow packages. User services: ROOT-STEPS §16 (user runs
  `systemctl --user enable --now mpd mpd-mpris`). Bar: MPRIS name "Music
  Player Daemon" → MPD (dropped again: not needed).

- **2026-11-14** — `tauon-music-box` added to pacman.txt (Media; official
  extra repo, so no PKGBUILD review). Uses MPRIS (bar widget, media keys) and
  libappindicator (tray). User installs it.

- **2026-11-13** — zathura `:open` Tab completion seemed to offer only recent
  files: zathura (completion.c list_files_for_cc) adds the "Recent files"
  group (show-recent, default 10) before the "Files" group (folders +
  supported documents of the typed folder) and shows 15 items, so recents
  filled the list. Now `show-recent 0`, `n-completion-items 20`. Relative
  names complete from zathura's cwd (~ when started from apps). File:
  `zathura/.config/zathura/zathurarc`.

- **2026-11-13** — 3-finger workspace swipe made non-natural (user request),
  matching the touchpad's non-natural scrolling:
  `gestures.workspace_swipe_invert = false` (Hyprland default true). File:
  `hypr/conf/input.lua`.

- **2026-11-13** — Marquee: returning title's first letters dimmed then
  brightened (left fade weakened while the start was already inside the 40 px
  fade zone). Now the fade is a function of the outgoing title only: builds
  over offset 0…40 px, and switches off once offset > title width (only the
  48 px gap is under the zone then, so the switch is invisible); the next copy
  enters unfaded. Invariant: gap (48) > fadeZone (40). File:
  `bar/MediaModule.qml`.

- **2026-11-13** — Marquee smoothness: steps use an exponentially smoothed
  frame time (α 0.1) so uneven frame delivery doesn't show as uneven motion;
  the moving strip's layer is rendered at 2× with mipmaps so sub-pixel
  positions don't shimmer (still crisp at rest). File: `bar/MediaModule.qml`.

- **2026-11-13** — Marquee: left-edge fade popped off when the title snapped
  home (it faded the incoming start, then switched off at once). Now the left
  fade strength = min(offset, cycle − offset) / 40 px, so it eases in as the
  title leaves and is already zero when the next lap's start arrives. File:
  `bar/MediaModule.qml`.

- **2026-11-13** — Marquee slowed down after the mouse left the bar. Cause: Qt
  animations advance a fixed step per rendered frame; with the cursor gone the
  compositor delivers the bar's frames less regularly, so "animation time"
  ran slower than real time. Fix: FrameAnimation integrating real `frameTime`
  (capped at 50 ms) at a constant 55 px/s, 0.4 s smoothstep ease-in at the
  start; states idle / loop / finishing (finish the lap, stop at the start).
  File: `bar/MediaModule.qml`.

- **2026-11-13** — Music title scrolling reworked (user request): one-way
  marquee (title + 48 px gap + copy, endless left scroll at 55 px/s, linear,
  0.35 s delay on hover); on mouse-out it finishes the current lap and stops
  at the start (re-hover continues). Stutter cause: StyledText uses
  NativeRendering (glyphs snapped to whole pixels → 1-px steps every few
  frames at 144 Hz). Fix: the moving strip is a layer (texture rendered once,
  layer.smooth) slid at sub-pixel x. File: `bar/MediaModule.qml`.

- **2026-11-13** — Music tooltip no longer repeats the title (it's in the bar and
  scrolls on hover): now "<player> · click: play/pause · scroll: skip", with
  tidy names for MPRIS identities like "Mozilla zen" → Zen. File:
  `bar/MediaModule.qml`.

- **2026-11-13** — Music title scrolls on hover (user request): only when it's
  cut off; loop = 0.5 s pause, glide to the end (45 px/s, InOutSine), 1.2 s
  pause, glide back, 0.8 s pause. Mouse away → rolls back to the start
  (OutCubic, ~2.5× faster) instead of jumping; new track resets to the start.
  Fade mask follows: left edge fades once scrolled, right edge until the end
  shows. File: `bar/MediaModule.qml`.

- **2026-11-13** — Bar follow-up: tray drag flickered/jittered: the drag offset
  was measured in the icon's own coordinates while the icon moved under the
  cursor (feedback). Now measured with `mapToItem(root, …)` (8 px threshold,
  onCanceled reset). Layout: tray leftmost of the right group (Pomoclock last,
  then the coffee cup), recording after the cup, brightness moved next to
  audio. Music squeezed to ~160 px (centred with `2 × min(gap)`): now
  `x = clamp(centred, gapLeft, gapRight − width)`, `maxWidth = gap`. Files:
  `bar/Bar.qml`, `bar/Tray.qml`.

- **2026-11-13** — Bar (user request): **brightness** control left of the tray
  (sun glyph by level + level bar; scroll ±5%, middle-click full ↔ previous;
  click → `popups/BrightnessMenu.qml`: % header, slider with ±5% sun buttons,
  10/25/50/75/100 presets; the brightness OSD stays quiet while it's open).
  `Brightness.set()` coalesces slider moves (40 ms) into `brightnessctl -q -n2
  set N%`, min 1%. **Tray order**: drag an icon and drop it; order saved by
  SNI Id in `Quickshell.statePath("tray-order.json")` (FileView + JsonAdapter;
  absent apps keep their slot), Pomoclock (`io.github.pomoclock.Pomoclock`)
  always last before the coffee cup; recording indicator moved left of
  brightness. Files: `bar/{Bar,Tray,BrightnessIcon}.qml`,
  `popups/BrightnessMenu.qml`, `services/Brightness.qml`, `osd/Osd.qml`.

- **2026-11-13** — pastel-pink theme deleted completely (user request):
  `lockscreen/themes/`, `system/root-steps/6-login-theme.sh`, ROOT-STEPS §16,
  its local bg.jpg and preview images. `scripts/lock.sh` only knows qylock's
  themes again (default winter); 4-login.sh checks winter only. The entries
  below describe what it was.

- **2026-11-13** — Back to qylock's **winter** (user didn't like the pastel
  theme). `scripts/lock.sh` defaults to winter again (still runs
  lock_shell.qml itself; `lock.sh pastel-pink` keeps the other theme
  reachable). SDDM had been switched at 18:57 by the pre-rename
  6-login-theme.sh (`Current=strawberry-milk`, theme in
  /usr/share/sddm/themes/strawberry-milk, backup theme.conf.before-strawberry
  = winter): user restores that (root). The PAM shim patch stays: it fixes the
  empty-Enter hang for winter too.

- **2026-11-13** — pastel-pink theme: background → wallhaven 3z86od (sakura
  branch, pink moon; user's pick; 2560×1440 JPEG, not in git); font →
  JetBrainsMono Nerd Font only (bundled Fredoka/Quicksand removed).

- **2026-11-13** — Lock/login theme tweaks (user request): renamed
  strawberry-milk → `pastel-pink` (folder, SDDM theme name, root-step 6, docs);
  removed the bow emoji, hearts (floating, avatar badge, password dots, ♡ in
  texts) and flowers, leaving 12 faint sparkles; corner radius card 44 → 20,
  pills/buttons fully round → 14 (avatar stays a circle). Previews with four
  wallpapers rendered off-screen to ~/Pictures/lockscreen-previews/.

- **2026-11-13** — New lock/login theme `lockscreen/themes/pastel-pink`
  (user request: pastel pink, cute; may differ from the rice palette). Own QML
  in qylock's theme format (sddm/userModel/sessionModel/config contract; reads
  the shim's `sddm.lastError`); bundled Fredoka + Quicksand (OFL); bg.jpg =
  wallhaven 5ym379 (SFW search, not in git; gradient fallback). Previewed
  off-screen with `qml` + stub sddm object (QT_QPA_PLATFORM=offscreen,
  grabToImage). `scripts/lock.sh` now runs qylock's lock_shell.qml itself with
  QS_THEME_PATH → this theme (qylock's lock.sh hard-codes winter); optional
  theme name argument. SDDM: `system/root-steps/6-login-theme.sh` (ROOT-STEPS
  §16) copies it to /usr/share/sddm/themes and selects it; 4-login.sh checks
  accept either theme.

- **2026-11-13** — Lock screen after opening the lid (on AC, locked ~1 h): no
  error on a wrong password, then nothing unlocked; user rebooted from the lock
  screen. Not SDDM: qylock's Quickshell lock looks the same. The journal shows
  no PAM activity at all after the lid opened (a wrong password at 16:00 was
  logged normally). Cause (qylock shim): Enter on an empty box calls
  pam.start() with no password; PAM asks for one, the shim only answers when it
  has one, so the conversation waits forever and every later login() hits an
  active PamContext (start() fails silently). Fix: GPL patch to the shim (skip
  empty, answer/restart a waiting conversation, onError + 20 s watchdog, pass
  PAM's message, e.g. faillock lockout) + winter theme shows it. Files:
  `lockscreen/patches/qylock-lockscreen.patch`, `lockscreen/apply-patches.sh`,
  `lockscreen/README.md`, `install.sh`. User runs apply-patches.sh.

- **2026-11-13** — zathura dark mode (Ctrl+R): itemize bullets showed as white
  dots with a dark ring in a pdfTeX lecture-notes PDF. Cause: that PDF draws
  every bullet as a 34×34 stencil image (`pdfimages -list`: 146 identical
  images), and `recolor-reverse-video true` keeps image colours, so the
  bullets were excluded from recolouring. Fix: `recolor-reverse-video false`
  (images recoloured too; Ctrl+R for photos). File: `zathura/.../zathurarc`.

- **2026-11-12** — Nuclear removed at the user's request: `nuclear-player-bin`
  out of aur.txt, bar Nuclear tweaks reverted (Media.qml / MediaModule.qml as
  before 23a48c1). yt-dlp stays (comment updated). fastfetch back to the
  original small Arch logo (`arch_small`, plain `fastfetch` in .zshrc); the
  picture card files were deleted, `scripts/fastfetch-logo.sh` kept (the
  apply.sh hook only runs while the config uses logo.png). The shorter
  cpu/disk lines stay. Uninstall + data cleanup: user runs (see chat).

- **2026-11-12** — Nuclear 1.54 (Tauri rewrite) has no track download feature:
  none in the player source (the "download" strings are its yt-dlp
  self-installer), old download issues closed as legacy-Electron only, a
  2026-10 discussion requesting it is unanswered. Nuclear keeps its own yt-dlp
  nightly in ~/.local/share/com.nuclearplayer/ytdlp/, so the system `yt-dlp`
  isn't needed for it (kept for mpv + manual downloads; comment fixed).

- **2026-11-12** — Nuclear in the bar's music widget. Nuclear (Tauri/WebKitGTK)
  shows up in MPRIS only via WebKit's generic bridge: "Nuclear Player", status
  stuck at Paused. Its MediaSession plugin (rkben/nuclear-plugin-mediasession
  v0.1.0, read: ~150 lines, only navigator.mediaSession + Nuclear API; sha256
  matches the registry) feeds real metadata/state into that bridge. Bar:
  tooltip shows "Nuclear" instead of the raw identity. Nuclear also serves MPD
  on 127.0.0.1:6600 and its MCP server on 127.0.0.1:8800/mcp (useful for
  checking what it plays). Files: `services/Media.qml`, `bar/MediaModule.qml`.

- **2026-11-12** — `yt-dlp` added to pacman.txt (Media): needed by Nuclear's
  YouTube streaming plugin; mpv uses it for YouTube URLs too. No Apple Music
  integration exists for Nuclear (none in NuclearPlayer/plugin-registry).

- **2026-11-12** — Nuclear music player (user request): `nuclear-player-bin`
  added to aur.txt after reading the PKGBUILD [c8b54d2] and the .deb it
  downloads (checksum matches; 3 files: binary, Nuclear.desktop, icon; no
  maintainer scripts). Tauri app (WebKitGTK); window class
  `nuclear-music-player`.

- **2026-11-12** — Reactor animation removed again at the user's request
  (reverted 89e13e7: fastfetch-reactor.py deleted, reactor.png deleted,
  python-pillow dropped from pacman.txt). fastfetch is back to the r1 picture
  card (`logo.png`, scripts/fastfetch-logo.sh) exactly as before.

- **2026-11-12** — fastfetch logo → animated ASCII art (user request): two
  cooling towers + reactor dome in neutral grey, red glow pulsing inside, red
  steam rising, rings from the core (nf-md-radioactive U+F043C; ☢ isn't in
  JetBrainsMono). `scripts/fastfetch-reactor.py` (Pillow) draws it with the
  terminal font into an APNG (24 frames × 90 ms, 300×345, transparent, bloom);
  fastfetch logo type `kitty-icat` → kitty loops it itself (no process, no
  input interference). Generated by `install.sh` step render (not in git);
  python-pillow in pacman.txt. The picture card (fastfetch-logo.sh) stays
  available; apply.sh rebuilds it only while the config uses logo.png.

- **2026-11-12** — Folder locking in Nautilus + on PATH (user request).
  Right-click folder → "Lock with Password…", `.locked` file → "Unlock…"
  (`nautilus/…/extensions/lock_folder.py` → `scripts/lockdir-gui.sh`: zenity
  password form / progress / errors, notify-send on success; password piped to
  `lockdir.sh --password-stdin`). New stow package `bin/` puts `lockdir` and
  `unlockdir` in `~/.local/bin` (added to NO_FOLD_DIRS, so it stays a real
  folder; zsh aliases removed). zenity listed in pacman.txt; float-zenity
  window rule. Needs `nautilus -q` once.

- **2026-11-12** — New `scripts/lockdir.sh` (aliases `lockdir` / `unlockdir`,
  user request): folder → `NAME.locked` (tar+zstd, gpg symmetric AES-256,
  s2k SHA512 ×65M, `--no-symkey-cache`, password via fd 3), verified with
  `tar -d` against the folder before the folder is removed; unlock extracts
  into a hidden temp dir first. Caveat: /home snapper snapshots keep the
  plaintext until they expire. Docs: zsh/SHELL-CHEATSHEET.md.

- **2026-11-12** — Wallpaper thumbnails could show the wrong picture after
  renaming files (user removed w6/w7/w10 and renumbered: w9.png → w7.png kept
  the deleted w7's thumbnail). Cause: thumbs were rebuilt only when the
  picture's mtime was newer than the thumbnail, and `mv` keeps mtime. Fix: also
  rebuild when the picture's ctime (updated by rename) is newer. File:
  `scripts/wallpaper.sh`.

- **2026-11-12** — Wallpaper reel showed w10, w11, w12 before w1: the file list
  used plain `sort`, which in the en_US locale ignores the dot and compares
  "w10png" < "w1jpg". Fix: `sort -V` (natural order). File:
  `services/Wallpapers.qml`.

- **2026-11-12** — fastfetch picture switched to ~/Pictures/Random/r1.jpg (user
  request; crop `1040x1193+500+40`). Bright line-art washed out under the old
  fixed contrast + bloom: the script now measures the card's mean brightness and
  darkens midtones (gamma) until it's ~45 % (never brightens dark pictures);
  bloom gentler (threshold 80 %, 0.25). r3 (crop `820x941+440+0`) still looks
  the same. File: `scripts/fastfetch-logo.sh`.

- **2026-11-12** — fastfetch picture card gets a styled look (user request):
  gradient map onto the palette (base → blue → lightblue → text), 2 px
  chromatic split, CRT scanlines, vignette, bloom, grain, then rounded corners
  + outline. All colors come from the active palette, so ALT+T re-tints it
  (apply.sh reruns the script, ~0.9 s). File: `scripts/fastfetch-logo.sh`.

- **2026-11-12** — fastfetch in a half-width kitty: stray "4" / "f" at the left
  edge next to the picture, and gpu/battery rows pushed down. Cause: kitty opens
  full-size, fastfetch prints (line wrap is off), then Hyprland tiles the window
  and kitty re-wraps the long cpu ("… @ 4.40 GHz") and disk ("… - btrfs") lines;
  the wrapped rest starts under the picture. Fix: shorter cpu/disk formats
  (values ≤ ~44 chars, fits ~92 columns). File: fastfetch template.

- **2026-11-12** — Nautilus "Copy as Path" (user request): nautilus-python
  extension in new stow package `nautilus/` (selected files → full paths, one
  per line; empty space → "Copy Folder Path"; Gdk clipboard). `nautilus-python`
  listed explicitly in pacman.txt. Needs `nautilus -q` once to load.
- **2026-11-12** — fastfetch shows a picture card instead of the Arch logo (user
  request, ~/Pictures/Random/r3.png). `scripts/fastfetch-logo.sh IMAGE [CROP]`
  copies it to `~/.config/fastfetch/logo-source.png` and makes `logo.png`
  (558×640 = 30×15 kitty cells at 13 pt, rounded corners, outline in the theme's
  lightblue; `theme/apply.sh` rebuilds it on theme switch). Crop for r3:
  `820x941+440+0`. Shown with logo type `kitty-direct`. Pictures are gitignored
  (`*.png`, `logo.crop`); without logo.png, .zshrc falls back to arch_small.
  If the kitty font size changes, adjust width/height in the fastfetch
  template. Files: `scripts/fastfetch-logo.sh`, fastfetch template,
  `zsh/.zshrc`, `theme/apply.sh`, `.gitignore`.

- **2026-11-11** — Added Rust support (user request). `rustup` in
  `packages/pacman.txt`; new `install.sh --only rust` step (stable toolchain +
  rust-analyzer + rust-src; also part of the normal `install.sh` run). Neovim:
  rust-analyzer from rustup (not mason, so it matches the compiler), clippy on
  save, rustfmt on save (skipped while no server runs), treesitter `rust`
  parser. Arch's rustup puts the rust-analyzer launcher in `/usr/lib/rustup/bin`
  (off PATH): Neovim uses that path directly; zsh appends it to PATH. zsh: `~/.cargo/bin` on PATH. Docs: nvim/CHEATSHEET.md §6,
  zsh/SHELL-CHEATSHEET.md. Files: `packages/pacman.txt`, `install.sh`,
  `nvim/.config/nvim/lua/plugins/{lsp,treesitter}.lua`, `zsh/.zshrc`.

- **2026-11-11** — Tray: room for Pomoclock's wide icon (the user's pomodoro
  app, `~/utilities/pomodoro`, not part of this repo). Its tray icon is a
  170×27 pill; the 20×20 slot squashed it. Tray items with id
  `io.github.pomoclock.Pomoclock` get a 170×27 slot drawn with a plain `Image`
  at that `sourceSize` (IconImage always requests a square pixmap, which
  Quickshell scales without keeping the aspect ratio). Other tray icons are
  unchanged. File: `bar/Tray.qml`.

- **2026-11-11** — Bluetooth headphones (ACCENTUM Plus) connected right after
  pairing but never again ("Connection refused (111)"); only forget + re-pair
  helped. Cause: no pairing agent was running (Quickshell has none; blueman-
  applet only ran while blueman-manager was open). BlueZ (AlwaysPairable=false,
  the default) then turns the adapter's Bondable off, so pairing used "No
  Bonding": btmon showed `Store hint: No`, `bluetoothctl info` showed
  `Paired: yes, Bonded: no`, and the key vanished on disconnect. Fix: autostart
  blueman-applet as the agent with its tray icon/connect pop-ups disabled
  (gsettings plugin-list); its PIN dialog floats centered. Pairings made before
  this fix must be done once more. Check: `bluetoothctl show` → `Pairable: yes`;
  after pairing `bluetoothctl info <MAC>` → `Bonded: yes`. Files:
  `hypr/conf/autostart.lua`, `hypr/conf/rules.lua`, `install.sh`,
  `popups/BluetoothMenu.qml`.

- **2026-11-11** — MGSV binocular zoom (mouse wheel) dead on Proton 10/11/
  Experimental (ValveSoftware/Proton #10200 → #743). Proton 9.0-4 is no longer
  usable: with the current Steam client lsteamclient never loads → "failed to
  load steam api", even on a fresh prefix. Fix: **GE-Proton11-12** (installed
  by hand into `compatibilitytools.d`; ProtonUp-Qt 2.16 hung on the download)
  with a fresh prefix: launches and the wheel works. File: `system/GAMING.md`.

- **2026-11-11** — Tray right-click menu didn't close on an outside click: it
  relied on HyprlandFocusGrab, which didn't clear for it. Fix: it's always
  opened by a click, so it's now a grabbing popup (`grabFocus: true`, the
  compositor dismisses it) with state synced in onVisibleChanged; a click on the
  same icon within 300 ms of that dismissal doesn't reopen it. File:
  `bar/TrayMenu.qml`.

- **2026-11-10** — Nautilus deleted permanently in ~/Downloads (and other §1.5
  subvolumes): GLib: "Trashing on system internal mounts is not supported" — a
  nested btrfs subvolume has its own st_dev but no mount entry. Fix (user runs):
  system/root-steps/5-trash-mounts.sh / ROOT-STEPS §15 mounts each subvolume at
  its path via fstab (nofail, x-gvfs-hide, x-gvfs-trash); trash then lives in
  <folder>/.Trash-<uid>. Test: `gio trash` a file in ~/Downloads.

- **2026-11-10** — No PDF thumbnails in Nautilus: no PDF thumbnailer installed
  (GNOME's come with Papers/Evince). Added stow package `thumbnailers/`
  (`~/.local/share/thumbnailers/pdf.thumbnailer`, pdftoppm from poppler, inline
  `sh -c` because the thumbnail sandbox can't see ~/dotfiles). Nautilus reads
  thumbnailers at start: quit it (`nautilus -q`) after changes. Failed attempts
  are cached in ~/.cache/thumbnails/fail/ (delete to retry). Test without
  Nautilus: GnomeDesktop.DesktopThumbnailFactory via python gi.

- **2026-11-10** — Post-update check after the 82-package upgrade (Hyprland
  0.57.2, linux 7.2.15, nvidia-open 615.78.08-6, PipeWire 1.6.11, WirePlumber
  0.5.19, kitty 0.50.0, systemd 262.2, qt6-base 6.12.0-4). Nothing broke:
  `--verify-config` ok, no configerrors, one qs instance, no failed units,
  dGPU suspended, speaker sink active, kitty config parses, `update --check`
  clean. Boot log only has the usual HP ACPI BIOS errors. §1 table updated.

- **2026-11-10** — Review batch 4 (docs + root-step scripts): R15 ROOT-STEPS
  §5.0 yay bootstrap + 3-system.sh stops without yay; README says
  `./install.sh` (without --packages) never uses sudo. R16 README lid step.
  R44 ufw subnet-rule caveats. R45 1.5-home-subvolumes.sh: re-run after a
  failed copy stops with the finish command instead of "ok". R46 stale
  "(later)/step N" notes (ROOT-STEPS, 3-system.sh, §6, GAMING.md). R47 README /
  §5 no longer suggest running install.sh twice. R48 theme docs (4 dark themes,
  Vesktop, wallpaper comment). R49 font_pt comment. R50 §3 undo complete.
  R51 §2.2 map. R52 Outlook class wording. R53 stale Hyprland comments. R57
  example subnet generic. Review complete: all 57 issues handled (R37 Qt5 and
  R38 Teams X11 deliberately kept, see §5).

- **2026-11-10** — Review batch 3 (scripts, configs, security): R14 kitty
  remote-control socket moved from abstract @socket to $XDG_RUNTIME_DIR (0700).
  R31 wallpaper.sh apply notifies + keeps `current` on failure. R32 update.sh
  news window starts at the last *completed* upgrade and also flags recent
  manual-intervention items naming a pending package. R33 fwupd errors no
  longer read as "updates available". R34 notify-file.sh `timeout 1h`. R35 OCR
  preview escaped. R36 cursor/toolkit/Qt/Electron/GSK env exported to
  systemd+D-Bus (`hl.env(name, value, true)`). R37 Qt5 + R38 Teams X11 kept,
  documented (§5). R39 nested nvim leaves kitty opacity alone. R40 LSP `gr`
  nowait. R41 `lnew` alias. R42 theme picker -no-custom, apply.sh notifies.
  R43 palettes may override style keys (render.sh reads palette first);
  Catppuccin glass_alpha 0.85. R54 small script fixes. R56 dead code removed
  (7 glyphs, Bluetooth.glyph, Recorder.region, THEME_NAME, empty cava/).

- **2026-11-10** — Review batch 2 (Quickshell, low): R20 replay mode announces
  on start / failure (stderr + onExited). R21 ScriptModel in Audio/Bluetooth
  menus. R22 recording popup closes with its icon. R23 Overlays.toggle treats an
  overlay on an unplugged monitor as closed. R24 stats reset on close. R25 kill
  button only for own processes (sysstats gains "user"), never qs; failure
  notifies. R26 `top` runs with a neutral HOME + numeric row guard. R27 battery
  warning state persists across reloads. R28 Wi-Fi IP re-read after (re)connect.
  R29 OSD only on the focused monitor. R30 reel thumbnails only while open.
  R55 battery minutes, Shift+Tab in power menu, cheat sheet load error, per-core
  bars animate (model = count). Gotcha: PersistentProperties can't carry a JS
  object across reloads ("JSValue can't be reassigned to another engine"):
  store JSON strings.

- **2026-11-10** — Code review batch 1 (high/medium; review = 12 area
  reviewers + adversarial verification, plan in ~/.claude/plans). R1 rclone
  unit ordering cycle (After=default.target removed: Drive never mounted after
  reboot). R2 StyledText defaults to PlainText (MPRIS titles, SSIDs, BT names,
  summaries were rendered as rich text incl. remote <img>); bodies keep markup
  via Notifications.bodyText() with images stripped. R3 power menu ignores key
  auto-repeat for activation (holding R rebooted without countdown). R4 udiskie
  autostarted. R5 replaced notifications (replaces_id) re-announced via
  signal hooks + Qt.callLater, history sorted by arrival time. R6 BarIcon
  `open` false without a popup (coffee cup was always blue). R7 Chromium web-app
  notifications focus their chrome-<host> window (Outlook). R8/R12/R13
  wifi-enterprise.sh: optional server-name pin (+ TOFU offer), password via
  `nmcli connection edit` stdin (not argv; editor trims edge spaces, those fall
  back to argv), SSID sanitised. R9 lock-screen crash recovery documented.
  R10/R11 scripts/lid.sh: lid close disables eDP-1 when another monitor is on
  (runtime `hl.monitor` via `hyprctl dispatch 'function() ... end'`), hypridle
  screens-on skips the panel of a closed lid. Also R17-R19 (notification times
  + unread persist across reload as JSON string; transient expire; bell cleared
  on center close).

- **2026-11-09** — Lid: lock only when plugged in, suspend on battery (user
  request; a Steam download stopped on lid close). logind drop-in
  `system/etc/logind.conf.d/10-lid.conf` (ROOT-STEPS §14, user installs) +
  Hyprland lid binds turning eDP-1 off/on (`hypr/conf/keybinds.lua`; switch
  names from 0.57.1 source: `switch:on:Lid Switch` = closed).

- **2026-11-09** — Touchpad switched from natural to normal scrolling (user
  request). File: `hypr/conf/input.lua`; §5 table.

- **2026-11-09** — Firefox (uninstalled) still showed in the rofi launcher, and
  Teams/Vesktop/Claude (installed later) were missing from it. Cause:
  `drun-use-desktop-cache: true` — rofi never rebuilds that cache by itself.
  Fix: cache off (54 .desktop files parse instantly on NVMe), stale
  `~/.cache/rofi-drun-desktop.cache` deleted. Files: rofi config template
  (+ rendered), `packages/base.txt` (firefox removed).

- **2026-11-09** — Enterprise Wi-Fi (user wants IISc `iiscwlan`, WPA2/WPA3
  Enterprise): new `scripts/wifi-enterprise.sh`; the Wi-Fi menu's "Set up…" for
  enterprise networks opens it in a floating kitty instead of
  nm-connection-editor. Files: `scripts/wifi-enterprise.sh`,
  `popups/NetworkMenu.qml`, `hypr/conf/rules.lua`. §4.2c.

- **2026-11-09** — Step 21: README (screenshots in `docs/screenshots/*.jpg`,
  generated keybind table, install, recovery, docs, credits), MIT LICENSE,
  `lockscreen/README.md` (qylock used unmodified, GPL notice rule). Fixes found
  while taking screenshots: cheat-sheet rows with two long combos wrapped with
  a leading "/" (keycap area 210 → 250 px, `cheatsheet/CheatSheet.qml`);
  NetworkMenu rows read properties of a network that just vanished from a scan
  (null guards, `popups/NetworkMenu.qml`, `services/Network.qml`).
  README screenshots: take them on an empty workspace with only your own demo
  windows (never the user's windows); README table: `scripts/keybinds-to-md.sh README.md`.

- **2026-11-09** — Step 20: `scripts/update.sh` + `update` alias (news gate,
  watch list, yay, post-checks, `--check`), §2.7 timers/firmware/diagnosis,
  `packages/base.txt`; `btop` and `claude-code` (AUR, PKGBUILD reviewed) added
  to the lists. reflector fix confirmed deployed (mirrorlist HTTPS IN/SG/BD).
  Versions in §1 re-checked.

- **2026-11-09** — Step 19 (general part; the user asked to leave per-game
  configs until the games are installed): MangoHud config (theme template,
  compact, RTX 3050 stats, Left Shift+F12), gamemode.ini, ROOT-STEPS §13
  (gamemode group), GAMING.md. Verified: MangoHud on Intel vs NVIDIA (name
  line), tearing active through iGPU scanout, controller on xpad.

- **2026-11-09** — Light themes removed at the user's request (Catppuccin
  Latte palette, the palettes' `mode` key, light branches in apply.sh/qt.sh,
  the picker's mode label, `scripts/qs.sh`; Quickshell back to the
  `IconTheme Papirus-Dark` pragma + plain `qs` in autostart). Every theme is
  dark; apply.sh always sets prefer-dark / Adwaita-dark / Papirus-Dark.
  **Don't re-add light themes unless the user asks.**

- **2026-11-09** — Step 18: Neovim (lazy.nvim, Nord, which-key, Telescope,
  Treesitter main, mason + lspconfig + blink.cmp, neo-tree, lualine,
  bufferline, gitsigns, lazygit, toggleterm, vimtex) + zathura. Verified:
  startup ~40 ms with a file, LSP attaches (lua_ls, bashls), LaTeX compile →
  PDF + SyncTeX, inverse search, kitty opacity + padding colour by pixel
  sampling. `nvim` and `zathura` added to STOW_PACKAGES.

- **2026-11-09** — Bug sweep (two review passes over all scripts + QML, each
  finding verified before fixing). Shell: hypridle `inhibit_sleep = 3` (suspend
  could happen before qylock was up); battery-only suspend now checks
  `Discharging` and keeps checking (`idle-suspend.sh`); sysstats disk JSON broke
  on labels with spaces (`findmnt -J`); clipboard Enter on no match wiped the
  clipboard (`-no-custom`) + thumbnail pruning; colorpick swatch caching;
  lock.sh pgrep anchored; apply.sh rollback; install.sh bat/gio order;
  screenshot same-second names. QML: overlay IPC dead on a 2nd monitor
  (Overlays singleton); battery warnings doubled per monitor (Power singleton);
  battery health never shown (BAT0); Wi-Fi password wiped while typing
  (ScriptModel) + enterprise networks → nm-connection-editor + Enter bypassed
  the 8-char check; theme switch reset coffee cup/DND and orphaned recorders /
  udevadm (PersistentProperties, onDestruction, pdeathsig, apply.sh guard);
  popup closed while hovering its buttons (HoverHandler); stats "End process"
  could hit a moved row (list frozen while hovered/armed); notification
  actions reachable from the center + default action; reel reloaded thumbs on
  every open; touchpad
  scroll jumped volume/months (WheelSteps); recorder said "saved" on failure;
  notification maps never pruned (+ history cap 100); stale stats sample after
  reopen; empty tooltips; idle screen animating behind the lock; power-menu
  greeting stuck; long titles under the tray; audio menu taller than screen.

- **2026-11-09** — Step 17: Outlook web app, teams-for-linux-bin, vesktop-bin
  (palette theme), claude-desktop (PKGBUILDs reviewed); msteams:/discord:
  handlers; call pop-out rule; notification click focuses the app.
  install.sh fix: no-fold dirs get per-file backups only.
- **2026-11-09** — Step 16: Nautilus Nord (scoped libadwaita variables),
  Open in Terminal → kitty, Google Drive (rclone unit + sidebar bookmark),
  Qt palette (qt5ct/qt6ct), default apps (hyprland-mimeapps.list), APPS.md,
  ROOT-STEPS §11. Nord GTK3 theme skipped (see §5).
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

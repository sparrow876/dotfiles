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
updated 2026-11-10 after the 82-package upgrade.
BIOS F.28, Intel ME 16.1.32.2418, SSD (Micron MTFDKBA512TFH) firmware HPS0043.
After an update, compare with `pacman -Q <pkg>` and update this table.

| Component | Version |
|-----------|---------|
| Kernel | linux 7.2.15-arch1-1 |
| Hyprland | 0.57.2 (Lua config) |
| Quickshell | 0.3.2 |
| NVIDIA | nvidia-open 615.78.08-6 / nvidia-utils 615.78.08-2 |
| Mesa | 26.2.6 |
| PipeWire / WirePlumber | 1.6.11 / 0.5.19 |
| awww (ex-swww) | 0.12.1 |
| hypridle | 0.1.8 |
| rofi | 2.0.0 (native Wayland) |
| kitty | 0.50.0 |
| gpu-screen-recorder | 6.1.7 |
| Steam / MangoHud / GameMode | 1.0.0.87 / 0.8.4 / 1.8.2 (gamescope 3.17.0) |
| SDDM | 0.21.0 (X11 greeter) |
| Neovim | 0.12.6 (plugins pinned in `nvim/.config/nvim/lazy-lock.json`) |
| zathura | 2026.10.23 (+ pdf-mupdf) |
| TeX Live | 2026 (basic, latexextra, fontsrecommended, binextra) |

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
| `quickshell/.config/quickshell/shell.qml` | entry: one `Variants` per screen for Bar, OSD, StatsPanel, PowerMenu, WallpaperReel, IdleScreen, CheatSheet, NotificationPopups; `popups` IPC |
| `quickshell/…/Theme.qml` | generated singleton: colors, fonts, sizes |
| `quickshell/…/services/` | singletons: Audio, Bluetooth, Brightness, IdleInhibit, Keybinds, Media, Network, Notifications, Overlays (IPC for the per-monitor overlays), Popups, Power (battery + low-battery warnings), Recorder, SystemStats (+`sysstats.sh`), Wallpapers |
| `quickshell/…/bar/` | Bar + modules (`*Icon.qml`, Workspaces, MediaModule, Battery, Clock, Tray, TrayMenu, Bell) |
| `quickshell/…/popups/` | `PopupFrame` (shared) + Network/Bluetooth/Audio menus, Calendar |
| `quickshell/…/notifications/` | popups + center |
| `quickshell/…/components/` | StyledText, Icon, Glyphs (all glyphs), Tooltip, Toggle, Slider, IconButton, TextButton, Card, Spinner, Separator, LevelBar, Graph, RingGauge, WheelSteps (scroll → whole steps) |
| `quickshell/…/{osd,panel,powermenu,wallpaper,idle,cheatsheet}/` | one overlay each |
| `scripts/` | shell helpers (update, wifi-enterprise, screenshot, ocr, colorpick, clipboard, emoji, lock, logout, idle-dim, idle-suspend, lid, wallpaper, record, notify-file, theme-picker, keybinds-to-md.sh + keybinds.jq, theme-colors.sh (generated)) |
| `theme/` | palettes, style, templates, `render.sh`, `apply.sh`, README |
| `system/` | ROOT-STEPS.md, root-steps scripts, units (platform profile, paccache), etc (reflector.conf, logind.conf.d/10-lid.conf) |
| `systemd/` | `environment.d/10-rice.conf` (env before Hyprland starts), `systemd/user/rclone-gdrive.service` |
| `applications/` | `.desktop` files: Outlook web app, nvim in kitty |
| `xdg/` | `hyprland-mimeapps.list` (default apps) |
| `qt/` | qt5ct/qt6ct colour files (generated) |
| `vesktop/` | Vesktop theme `rice.theme.css` (generated) |
| `zsh/`, `kitty/`, `starship/`, `fastfetch/`, `lazygit/`, `bat/`, `rofi/`, `gtk/` | app configs (stowed) |
| `nvim/` | Neovim (Nord): `init.lua`, `lua/{options,keymaps,autocmds}.lua`, `lua/plugins/*.lua` (one file per topic), `lazy-lock.json`; `CHEATSHEET.md` (not stowed) |
| `zathura/` | zathurarc (Nord, SyncTeX, recolor on Ctrl+R) |
| `mangohud/` | MangoHud.conf (generated from `theme/templates/mangohud/…`) |
| `gamemode/` | `gamemode.ini` (renice, screensaver inhibit) |
| `thumbnailers/` | `pdf.thumbnailer` (PDF thumbnails in Nautilus via pdftoppm) |
| `system/GAMING.md` | Steam setup, launch options, controller, per-game notes |

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
| `notifications` | `dnd`, `clear`, `status`, `clickLatest` | — |
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
| `snapper-timeline` / `snapper-cleanup` | hourly/daily home + root snapshots, pruned by limits | ROOT-STEPS §1 |
| snap-pac (pacman hook, not a timer) | pre/post snapshot around every pacman transaction | ROOT-STEPS §1 |
| `paccache.timer` | weekly, keeps the last 2 versions of each package | ROOT-STEPS §6 |
| `reflector.timer` | weekly, 20 fastest HTTPS mirrors (IN, SG, BD) | ROOT-STEPS §6 |
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
- **Restart**: `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
  Never `qs kill` (stops one instance only → duplicates stack up). Restart for visual/CPU checks (hot reload keeps stale
  layer sizes). A restart clears notification history and stops replay mode.
- **Hot reload** (any .qml save, every theme switch) recreates all singletons
  and does NOT stop child processes: state that must survive goes in
  `PersistentProperties { reloadableId }` (coffee cup, DND); long-running
  children are stopped in `Component.onDestruction` and started via
  `setpriv --pdeathsig <SIG>` so they also die if qs is killed/crashes
  (udevadm, gpu-screen-recorder). theme/apply.sh refuses to switch while recording.
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
  (read at startup only; it overrides the `QS_ICON_THEME` env var). All themes
  are dark, so it never changes.
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
- Qt: qt5ct/qt6ct, Fusion + generated `qt/.config/qt*ct/colors/rice.conf`;
  `theme/qt.sh` writes `qt*ct.conf` (absolute path → not committed) on install
  and every theme switch. Kvantum Manager always draws in Kvantum's own style,
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
  `theme/qt.sh` wrote absolute-path configs into the repo (removed, now
  gitignored). After any stow change: `ls -la ~/.config | grep -- '->'` and
  check no-fold dirs are real directories.

### 4.8 qylock

- Pinned at c2933f2 in `~/.local/src/qylock` (GPL-3.0, not copied into this
  repo). `lock.sh` exports `QS_THEME` from `~/.config/qylock/theme`, runs
  `quickshell -p lock_shell.qml` (WlSessionLock + PAM). Its `hyprctl keyword`
  call is harmless in Lua mode (`allow_session_lock_restore` is set in look.lua).
- SDDM's Arch PAM file already has `pam_gnome_keyring` (auth + session).
- **Patched** (GPL patch `lockscreen/patches/qylock-lockscreen.patch`, applied
  by `lockscreen/apply-patches.sh`, also run by install.sh step clones): the
  lock screen's PAM shim. Re-run after qylock's `quickshell.sh`; `--revert`
  before bumping the pinned commit. The lock screen uses PAM service `login`
  → system-auth → pam_faillock (defaults: 3 failures in 15 min → 10 min lock,
  `faillock --user $USER --reset` clears it; needs root).
- qylock's `lock.sh` ignores `~/.config/qylock/theme` (always "winter" unless a
  theme is passed as the first argument; `scripts/lock.sh` passes "$@").

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
| Theme | palette system + 4 dark themes (ALT+T) | user request |
| Replay toggled only from bar menu | ALT+Ctrl+R turns it on / saves; ALT+Ctrl+Shift+R toggles | indicator is hidden when idle |
| Bluetooth PIN confirm dialog | blueman-applet is the pairing agent (no tray icon): code confirmations arrive as notifications with Confirm/Deny, PIN entry as a small dialog | Quickshell has no agent API |
| Bar right side order | tray (drag to reorder, Pomoclock pinned last) · idle · recording · Wi-Fi · Bluetooth · audio · **brightness** · battery · bell · clock | user request 2026-11-13; brief had tray · recording · idle · … (no brightness) |
| Music position | centred when it fits, else slid into the gap between workspaces and tray, using all of it (max 420 px title) | the wide Pomoclock pill left only ~160 px around the centre |
| Dim to ~30 % | 30 % of the *current* brightness | user usually at ~18 % |
| Wallpapers never created | default palette gradient only if folder empty | no blank screen on fresh install |
| Logout | `hyprshutdown` if installed | graceful app shutdown |
| Music title truncation | soft fade, 420 px | user request |
| Nord GTK3 theme (e.g. Nordic) | not installed; Nautilus (GTK4) is Nord via scoped CSS, GTK3 dialogs use Adwaita-dark | Nordic AUR last updated 2022; a global GTK3 theme would fight the theme switcher |
| Qt via Kvantum | qt5ct/qt6ct Fusion + generated palette (Kvantum installed, unused) | follows theme switches; Kvantum needs SVG themes per palette |
| Default apps in `mimeapps.list` | `hyprland-mimeapps.list` | apps rewrite mimeapps.list (breaks stow) |
| Touchpad natural scroll | normal (traditional) scrolling | user's choice, 2026-11-09 |
| Lid close → lock + suspend | plugged in: lock only; battery: suspend | user's choice, 2026-11-09 (downloads keep running) |
| Electron apps native Wayland | Teams stays XWayland (package's --ozone-platform=x11) | screen sharing risk; no blur at 1x scale |
| Qt5 apps themed | only Qt6 (QT_QPA_PLATFORMTHEME=qt6ct) | no Qt5 apps installed; if one appears, launch it with QT_QPA_PLATFORMTHEME=qt5ct |

---

## 6. Known limitations / open items

- Bluetooth devices needing PIN/number confirmation: use Blueman (Advanced…).
  Possible later: a tiny BlueZ agent forwarding to Quickshell.
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
- Theme looks wrong: `theme/apply.sh blue-ice`.

---

## 9. Log

Newest first. Format: date — what broke / what changed, after which update,
root cause, fix, files.

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

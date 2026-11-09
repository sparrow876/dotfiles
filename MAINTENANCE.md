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

Recorded 2026-11-09 (build complete, steps 1–21; per-game setup waits for the games).
BIOS F.28, Intel ME 16.1.32.2418, SSD (Micron MTFDKBA512TFH) firmware HPS0043.
After an update, compare with `pacman -Q <pkg>` and update this table.

| Component | Version |
|-----------|---------|
| Kernel | linux 7.2.14-arch1-1 |
| Hyprland | 0.57.1 (Lua config) |
| Quickshell | 0.3.2 |
| NVIDIA | nvidia-open 615.78.08-4 / nvidia-utils 615.78.08-1 |
| Mesa | 26.2.6 |
| PipeWire / WirePlumber | 1.6.10 / 0.5.18 |
| awww (ex-swww) | 0.12.1 |
| hypridle | 0.1.8 |
| rofi | 2.0.0 (native Wayland) |
| kitty | 0.49.2 |
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
| `scripts/` | shell helpers (update, wifi-enterprise, screenshot, ocr, colorpick, clipboard, emoji, lock, logout, idle-dim, idle-suspend, wallpaper, record, notify-file, theme-picker, theme-colors.sh (generated)) |
| `theme/` | palettes, style, templates, `render.sh`, `apply.sh`, README |
| `system/` | ROOT-STEPS.md, root-steps scripts, units (platform profile, paccache), etc (reflector.conf) |
| `systemd/.config/environment.d/` | env for D-Bus/systemd-started apps (`GSK_RENDERER`) |
| `zsh/`, `kitty/`, `starship/`, `fastfetch/`, `lazygit/`, `bat/`, `rofi/`, `gtk/` | app configs (stowed) |
| `nvim/` | Neovim (Nord): `init.lua`, `lua/{options,keymaps,autocmds}.lua`, `lua/plugins/*.lua` (one file per topic), `lazy-lock.json`; `CHEATSHEET.md` (not stowed) |
| `zathura/` | zathurarc (Nord, SyncTeX, recolor on Ctrl+R) |
| `mangohud/` | MangoHud.conf (generated from `theme/templates/mangohud/…`) |
| `gamemode/` | `gamemode.ini` (renice, screensaver inhibit) |
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
| Nord GTK3 theme (e.g. Nordic) | not installed; Nautilus (GTK4) is Nord via scoped CSS, GTK3 dialogs use Adwaita-dark | Nordic AUR last updated 2022; a global GTK3 theme would fight the theme switcher |
| Qt via Kvantum | qt5ct/qt6ct Fusion + generated palette (Kvantum installed, unused) | follows theme switches; Kvantum needs SVG themes per palette |
| Default apps in `mimeapps.list` | `hyprland-mimeapps.list` | apps rewrite mimeapps.list (breaks stow) |

---

## 6. Known limitations / open items

- Bluetooth devices needing PIN/number confirmation: use Blueman (Advanced…).
  Possible later: a tiny BlueZ agent forwarding to Quickshell.
- notify-send with an unknown icon name shows Papirus' grey ✕ instead of the
  bell fallback.
- Per-game setup (Proton versions, launch options, Content Manager/CSP, ACC LAN
  ufw rules + serverList.json) waits until the games are installed (GAMING.md §7).
- Step 14 needs the user's qylock/SDDM runs + reboot before lock/SDDM/suspend
  are verified.
- Step 17 apps need the user's `yay` install + tests (call pop-out titles to
  confirm for the `call-popouts` rule; Vesktop theme to check visually).
- Build complete (steps 1–21). Open: per-game setup (GAMING.md §7), user's
  rclone sign-in, call pop-out titles for the `call-popouts` rule.
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
- Bar gone: `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`,
  then `qs log`. (From a TTY just log in again; autostart runs it.)
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

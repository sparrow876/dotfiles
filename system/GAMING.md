# Gaming

Steam games on this laptop: what's set up, how to launch games on the RTX 3050,
the controller, and per-game notes. Root steps for gaming: `ROOT-STEPS.md` §13.

Status (2026-11-09): general setup done and tested; **no games installed yet**.
The per-game sections at the end are filled in once each game is installed.

---

## 1. How it works on this laptop

- The desktop runs on the **Intel iGPU**; the **RTX 3050 sleeps** until something
  asks for it (battery life, quiet fans).
- Games must ask for it: every game gets the launch option below, which starts
  it on the RTX 3050 (`prime-run`), turns on GameMode and shows MangoHud.
- The picture still reaches the screen through the Intel iGPU. That is normal for
  this laptop's wiring (the internal screen is connected to the iGPU).
- Hyprland (`hypr/.config/hypr/conf/games.lua`) gives Steam games
  (`steam_app_*`) and gamescope: fullscreen, no blur/rounding/animations/borders,
  and **tearing** (lower input latency; verified working with this setup). While
  a game is fullscreen: notifications are muted (Do Not Disturb, critical ones
  still show) and the screen never dims/locks.
- The laptop screen has no VRR (FreeSync/G-Sync), so there's no VRR setting.

## 2. One-time Steam setup

1. **ROOT-STEPS §13** (gamemode group), then log out and back in.
2. Steam → **Settings → Compatibility** → turn on **Enable Steam Play for all
   other titles**, and pick the newest **Proton** (not "Experimental") as the
   default. Windows-only games then just install and run.
3. Optional, **GE-Proton** (community Proton with extra fixes some games need):
   open **ProtonUp-Qt** (from rofi) → *Add version* → GE-Proton → latest →
   *Install*, then restart Steam. It appears in each game's
   *Properties → Compatibility* list. Only use it for a game that needs it.
4. Steam library: the default `~/.local/share/Steam` is on the Linux (btrfs)
   disk and is **excluded from snapshots** (its own subvolume, ROOT-STEPS §1.5),
   so big game files don't fill the snapshot space. Want a second library
   folder? Make it a subvolume first (`mksubvol`, ROOT-STEPS §1.5), never on
   an NTFS (Windows) drive.

## 3. Launch options (every game)

Right-click the game → **Properties → General → Launch options**:

```
prime-run gamemoderun mangohud %command%
```

| Part | Does |
|------|------|
| `prime-run` | run the game on the RTX 3050 |
| `gamemoderun` | GameMode: CPU performance governor + higher priority while playing |
| `mangohud` | the performance overlay (section 4) |
| `%command%` | Steam puts the game here; keep it last |

Game-specific extras (from the per-game sections): environment variables go at
the **start** (`PROTON_LOG=1 prime-run gamemoderun mangohud %command%`), options
for the game itself at the **end** (`prime-run gamemoderun mangohud %command% -dx11`).

**Is the game really on the RTX 3050?** The first line of the MangoHud overlay
is the GPU's name: it must say **NVIDIA GeForce RTX 3050 Laptop GPU**. If it
says *Intel Graphics*, `prime-run` is missing from the launch options.
(Also: `nvidia-smi` in a terminal lists the game while it runs.)

**Is GameMode on?** While the game runs: `gamemoded -s` → "gamemode is active".

## 4. MangoHud (the overlay)

Top-left, compact, in the current theme's colors (it follows ALT + T).
Shows: GPU name, GPU load + temperature, CPU load + temperature, VRAM in use,
FPS (red < 30, yellow < 60), frame time + frame-time graph (a flat line = smooth;
spikes = stutters).

- **Left Shift + F12** shows / hides it.
- Config: `mangohud/.config/MangoHud/MangoHud.conf`, generated from
  `theme/templates/mangohud/...tmpl` (edit the template, then `theme/render.sh`).
- Only the RTX 3050's stats are shown (`pci_dev`), the name line still tells
  you which GPU the game uses.

## 5. Controller: 8BitDo Ultimate 2C Wired

Checked 2026-11-09: USB `2dc8:310a`, runs on the Linux kernel's **xpad** driver
(XInput / Xbox mode), no extra drivers or udev rules needed. It reports the
standard Xbox layout: A B X Y, LB RB, LT RT (analog), both sticks + clicks,
D-pad, View/Menu, Home, rumble. It also works in the browser
(gamepadtester.com).

In Steam: **Settings → Controller**: it should be listed. Steam Input (Steam's
remapping layer) can then remap any of those buttons per game.

<!-- L4/R4 section filled in below -->

Test again any time: `evtest` (pick "8BitDo Ultimate 2C", press buttons; Ctrl+C
quits) or gamepadtester.com.

## 6. Other notes

- **ProtonVPN: disconnect it before LAN races** (its kill switch can block the
  local network, and the VPN adds latency).
- A game won't start: set the launch options to
  `PROTON_LOG=1 prime-run gamemoderun mangohud %command%`, start it, then send
  me `~/steam-<appid>.log`. Also try another Proton version
  (*Properties → Compatibility*).
- Stutter the first minutes of a new game is usually shaders compiling; Steam's
  *Shader Pre-Caching* (Settings → Downloads) is on by default, leave it on.
- gamescope (a mini compositor some games like) is installed but not used by
  default; only if a per-game note says so.

---

## 7. Per-game notes (to do once installed)

Tell me when a game is installed; I'll check current ProtonDB reports and fill in
the recommended Proton version and launch options here.

| Game | Planned | Status |
|------|---------|--------|
| Metal Gear Solid V: The Phantom Pain | Proton; launch options from ProtonDB | not installed |
| BeamNG.drive | compare the native Linux build with Proton, pick the better one | not installed |
| Assetto Corsa | Proton + Content Manager + Custom Shaders Patch (community setup script: I read it and summarize it, you run it); controller via Content Manager | not installed |
| Assetto Corsa Competizione | Proton + launch options; LAN server: ports + ufw rule from your subnet only (ROOT-STEPS §7), `serverList.json` fallback; controller in ACC's settings | not installed |

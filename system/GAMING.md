# Gaming

Steam games on this laptop: what's set up, how to launch games on the RTX 3050,
the controller, and per-game notes. Root steps for gaming: `ROOT-STEPS.md` §13.

Status (2026-11-11): general setup done and tested. ACC and MGSV are installed
and run; BeamNG and Assetto Corsa aren't installed yet. Per-game sections are filled in as they are.

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
2. Steam → **Settings → Compatibility** → **Default compatibility tool:
   Proton Stable**. (Current Steam has Steam Play always on; this only picks
   which Proton Windows games use. "Proton Stable" follows the newest stable
   release by itself; the preselected "Proton Experimental" gets frequent test
   builds that occasionally break a game.) A single game can still use another
   version: *Properties → Compatibility*. Leave "Show all compatibility tools" off.
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

In Steam: **Settings → Controller**: it is listed (checked 2026-11-09). Steam Input (Steam's
remapping layer) can then remap any of those buttons per game.

### The extra L4 / R4 buttons (next to LB / RB)

In this (Xbox) mode the controller **doesn't send L4/R4 as their own buttons**:
the kernel driver, Steam and games can't see them (the Xbox 360 protocol has no
extra buttons). Instead you map them **on the controller itself** to copy
another button. From 8BitDo's manual:

1. **Hold L4 (or R4) + the button it should copy** (e.g. A, LB, a stick click),
2. **press the Mapping button** (small button on the front, left side).
3. The Mapping light blinks whenever the mapped button is pressed.
4. **To undo: repeat the same steps.** The mapping is saved in the controller.

Then Steam and every game see an ordinary button, and you can bind it per game.
Handy for racing: L4/R4 → shift down / shift up (map them to buttons you bind
to gear changes in the game).

(8BitDo's Ultimate Software, which can also remap and update the firmware, runs
only on Windows/macOS. Latest firmware v1.09 fixes a "ghost Home button" in
Xbox mode; only matters if you ever see that.)

**Other mode (not recommended):** holding **B while plugging in** starts
"Android" mode (USB id `2dc8:301d`). There L4/R4 *are* separate buttons, but
users report **rumble stops working** and the triggers may become on/off instead
of analog, bad for racing. Holding **X while plugging in** returns to the
normal Xbox mode (`2dc8:310a`), which is what this setup expects.

Sources: 8BitDo manual (download.8bitdo.com/Manual/Controller/Ultimate/Ultimate-2C-Wired-Controller.pdf),
product page (8bitdo.com/ultimate-2c-wired-controller), Linux `xpad.c` (no extra
buttons for 0x310a), SDL GameControllerDB.

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
| Metal Gear Solid V: The Phantom Pain | see below | **installed 2026-11-11**, runs |
| BeamNG.drive | compare the native Linux build with Proton, pick the better one | not installed |
| Assetto Corsa | Proton + Content Manager + Custom Shaders Patch (community setup script: I read it and summarize it, you run it); controller via Content Manager | not installed |
| Assetto Corsa Competizione | see below | **installed 2026-11-10**, runs |

### Assetto Corsa Competizione (Steam app 805550)

- Windows-only game (no Linux build), runs with **Proton 11.0** (the "Proton
  Stable" default). Starts out of the box (checked 2026-11-10).
- ProtonDB: **Gold, trending Platinum**, 164 reports, strong confidence. No
  open Proton issue needs a workaround (ValveSoftware/Proton #1420).
- Launch options: just the standard line, nothing game-specific:
  `prime-run gamemoderun mangohud %command%`
- Still to do: LAN server (ports + ufw rule from your subnet only, ROOT-STEPS §7;
  `serverList.json` fallback) and controller setup in ACC's settings.

### Metal Gear Solid V: The Phantom Pain (Steam app 287700)

- Windows-only game, runs with **Proton 11** (the "Proton Stable" default).
  Starts out of the box (checked 2026-11-11).
- ProtonDB: **Platinum**, 521 reports, strong confidence. Nothing open in
  ValveSoftware/Proton #124 needs a workaround.
- Launch options: just the standard line: `prime-run gamemoderun mangohud %command%`
  (without it the game runs on the Intel iGPU).
- **Mouse wheel (binocular zoom) does nothing on Proton 10/11/Experimental**: a
  Proton regression (ValveSoftware/Proton #10200, merged into #743, no fix yet as of
  2026-11-11). Works on **Proton 9.0-4**: Properties → Compatibility → "Force the
  use of a specific Steam Play compatibility tool" → Proton 9.0-4 (Steam downloads
  it). **Before the first launch on 9.0-4, move the old prefix aside**
  (`compatdata/287700` → `287700.bak`): a prefix made by Proton 11 and
  downgraded gives "failed to load steam api" (happened 2026-11-11). Saves live in
  Steam's `userdata/<id>/287700/local` (TPP_GAME_DATA*, TPP_CONFIG_DATA*), not in
  the prefix, so a fresh prefix loses nothing. Try the current Proton again after
  Proton updates (same prefix step in reverse).


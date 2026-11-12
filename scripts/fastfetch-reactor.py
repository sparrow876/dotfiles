#!/usr/bin/env python3
"""Animated ASCII-art logo for fastfetch: two cooling towers and a reactor dome
in neutral grey, with a red glow pulsing inside them, red steam rising from the
towers and red rings spreading from the core.

Writes an animated PNG (APNG, transparent background) drawn with the terminal
font, so it looks like coloured text. kitty plays it on a loop by itself
(fastfetch logo type "kitty-icat"), so no program keeps running in the
terminal and typing is never disturbed.

    scripts/fastfetch-reactor.py   ->  fastfetch/.config/fastfetch/reactor.png

Size: 30 x 15 terminal cells (kitty at 13 pt: about 10 x 23 px per cell),
drawn at 2x and scaled down for smooth edges. Needs python-pillow.
Edit the ART / colours below and run it again; open a new kitty to see it.
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

COLS, ROWS = 30, 15
CELL_W, CELL_H = 10, 23            # kitty cell at 13 pt, 1x screen
SCALE = 2                          # drawn at 2x, scaled down at the end
FRAMES = 24                        # one loop
FRAME_MS = 90                      # ~11 frames per second, ~2.2 s per loop
FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Regular.ttf"
FONT_BOLD = "/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Bold.ttf"
OUT = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..",
                   "fastfetch", ".config", "fastfetch", "reactor.png")

# Neutral concrete greys for the buildings
GREY_LIGHT = (196, 198, 202)
GREY = (140, 144, 150)
GREY_DARK = (92, 96, 104)
# Reds, from embers to white-hot
RED_DEEP = (110, 6, 10)
RED = (225, 22, 30)
RED_HOT = (255, 70, 50)
RED_WHITE = (255, 190, 170)

# The buildings. Rows 0-5 are sky (steam). Characters:
#   anything printable  drawn in grey (shade by row: lit top, darker base)
#   '~'                 inside a building: filled with the pulsing red glow
#   'R'                 the reactor core symbol (pulses)
#   ' '                 empty (steam / rings may pass through)
ART = [
    "                              ",
    "                              ",
    "                              ",
    "                              ",
    "                              ",
    "                              ",
    "  _______          _______    ",
    " (_______)        (_______)   ",
    "  \\~~~~~/          \\~~~~~/    ",
    "   )~~~(   .----.   )~~~(     ",
    "   |~~~|  /~~~~~~\\  |~~~|     ",
    "   (~~~)  |~~~~~~|  (~~~)     ",
    "  /~~~~~\\ |~~R~~~| /~~~~~\\    ",
    " /~~~~~~~\\|~~~~~~|/~~~~~~~\\   ",
    "/_________\\______/_________\\  ",
]
ART = [row.ljust(COLS)[:COLS] for row in ART]
# centre the drawing in the 30 columns
_shift = (COLS - max(len(r.rstrip()) for r in ART)) // 2
ART = [(" " * _shift + r)[:COLS] for r in ART]
TOWER_CENTERS = [5 + _shift, 22 + _shift]   # column of each tower's middle
TOWER_TOP = 6                      # row of the rim
CORE = next((r, c) for r, row in enumerate(ART) for c, ch in enumerate(row) if ch == "R")

GLOW_CHARS = " .:-=+*#%@"          # dim -> bright
STEAM_CHARS = "@Oo°·."             # young -> old


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def red_ramp(t):
    """0..1 -> deep red .. red .. hot .. white-hot"""
    t = max(0.0, min(1.0, t))
    if t < 0.5:
        return lerp(RED_DEEP, RED, t / 0.5)
    if t < 0.85:
        return lerp(RED, RED_HOT, (t - 0.5) / 0.35)
    return lerp(RED_HOT, RED_WHITE, (t - 0.85) / 0.15)


def rand(n):
    """Small deterministic hash -> 0..1 (same picture every run)."""
    n = (n ^ 61) ^ (n >> 16)
    n = (n * 9) & 0xFFFFFFFF
    n ^= n >> 4
    n = (n * 0x27D4EB2D) & 0xFFFFFFFF
    n ^= n >> 15
    return (n & 0xFFFF) / 0xFFFF


def frame_cells(f):
    """{(row, col): (char, color, bold, glows)} for frame f."""
    phase = 2 * math.pi * f / FRAMES
    cells = {}

    # Buildings in grey
    for r, row in enumerate(ART):
        shade = GREY_LIGHT if r <= TOWER_TOP + 1 else GREY if r < 12 else GREY_DARK
        for c, ch in enumerate(row):
            if ch not in " ~R":
                cells[(r, c)] = (ch, shade, ch == "=", False)

    # Red glow inside: brighter towards the bottom, flickering per cell
    for r, row in enumerate(ART):
        for c, ch in enumerate(row):
            if ch != "~":
                continue
            depth = (r - TOWER_TOP) / (ROWS - TOWER_TOP)
            # slow waves moving up through the building + a little per-cell sparkle
            wave = 0.5 + 0.5 * math.sin(phase * 2 + r * 0.9 + c * 0.35)
            sparkle = 0.5 + 0.5 * math.sin(phase * 3 + rand(r * 97 + c) * 2 * math.pi)
            t = 0.12 + 0.5 * depth + 0.28 * wave + 0.1 * sparkle
            cells[(r, c)] = (GLOW_CHARS[int(t * (len(GLOW_CHARS) - 1))], red_ramp(t), False, True)

    # Reactor core: pulses twice per loop
    pulse = 0.5 + 0.5 * math.sin(phase * 2)
    cells[CORE] = ("\U000f043c", red_ramp(0.75 + 0.25 * pulse), False, True)   # nf-md-radioactive

    # Rings spreading from the dome roof, between the towers (rows 6-9)
    dome_top = 10
    for k in range(2):
        age = ((f / FRAMES) + k / 2) % 1.0            # 0 -> 1, two rings apart
        radius = 1 + age * 4                          # cells
        r = dome_top - 1 - int(age * 3.5)
        cx = CORE[1] + 0.5
        t = 0.9 * (1 - age)
        for c in (int(cx - radius), int(cx + radius - 0.01)):
            if 0 <= r < ROWS and 0 <= c < COLS and ART[r][c] == " ":
                ch = "(" if c < cx else ")"
                cells[(r, c)] = (ch, red_ramp(t), False, True)

    # Steam: particles rising from each tower and fading, seamlessly looping
    for ti, cx in enumerate(TOWER_CENTERS):
        for p in range(16):
            seed = ti * 101 + p * 13
            birth = rand(seed) * FRAMES
            age = ((f - birth) % FRAMES) / FRAMES     # 0 (just out) -> 1 (gone)
            r = TOWER_TOP - 1 - int(age * 6.2)
            spread = (rand(seed + 1) - 0.5) * 2       # -1 .. 1
            drift = 0.8 * age                         # wind pushes a bit right
            wobble = 0.6 * math.sin(age * 6 + seed)
            c = int(round(cx + spread * (0.6 + age * 3.6) + drift + wobble))
            if 0 <= r < ROWS and 0 <= c < COLS and ART[r][c] == " ":
                ch = STEAM_CHARS[min(len(STEAM_CHARS) - 1, int(age * len(STEAM_CHARS)))]
                old = cells.get((r, c))
                t = 0.95 - 0.9 * age
                if old is None or old[1] < red_ramp(t):
                    cells[(r, c)] = (ch, red_ramp(t), age < 0.3, True)
    return cells


def render(cells, fonts):
    w, h = COLS * CELL_W * SCALE, ROWS * CELL_H * SCALE
    text = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dt, dg = ImageDraw.Draw(text), ImageDraw.Draw(glow)
    ascent = fonts[False].getmetrics()[0]
    for (r, c), (ch, color, bold, glows) in cells.items():
        x = c * CELL_W * SCALE
        y = r * CELL_H * SCALE + (CELL_H * SCALE - sum(fonts[False].getmetrics())) // 2 + ascent
        dt.text((x, y), ch, font=fonts[bold], fill=color + (255,), anchor="ls")
        if glows:
            dg.text((x, y), ch, font=fonts[True], fill=color + (255,), anchor="ls")
    # Bloom: blurred copies of the red parts, wide + tight, under the text
    glow = glow.filter(ImageFilter.MaxFilter(5))      # fatter strokes -> more light
    wide = glow.filter(ImageFilter.GaussianBlur(18 * SCALE / 2))
    tight = glow.filter(ImageFilter.GaussianBlur(5 * SCALE / 2))
    wide.putalpha(wide.getchannel("A").point(lambda v: min(200, int(v * 3.2))))
    tight.putalpha(tight.getchannel("A").point(lambda v: min(220, int(v * 2.2))))
    bloom = Image.alpha_composite(wide, tight)
    out = Image.alpha_composite(bloom, text)
    return out.resize((COLS * CELL_W, ROWS * CELL_H), Image.LANCZOS)


def main():
    size = 33 * SCALE // 2         # 2x of kitty's 13 pt (~16.5 px) font
    fonts = {False: ImageFont.truetype(FONT, size), True: ImageFont.truetype(FONT_BOLD, size)}
    frames = [render(frame_cells(f), fonts) for f in range(FRAMES)]
    out = os.path.normpath(OUT)
    tmp = out + ".tmp"
    frames[0].save(tmp, format="PNG", save_all=True, append_images=frames[1:],
                   duration=FRAME_MS, loop=0, disposal=1, blend=0)
    os.replace(tmp, out)
    print(f"fastfetch-reactor: {out.replace(os.path.expanduser('~'), '~')} "
          f"({len(frames)} frames, {os.path.getsize(out) // 1024} KiB)")


if __name__ == "__main__":
    main()

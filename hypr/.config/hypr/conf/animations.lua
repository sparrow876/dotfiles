-- Animations: smooth, quick, calm. Glide in and settle, no bounce or overshoot.
-- `speed` is in deciseconds: 2.8 = 280 ms.

hl.config({ animations = { enabled = true } })

-- Curves (cubic bezier control points). None overshoot past 1.0.
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })

local function anim(leaf, speed, curve, style)
    hl.animation({ leaf = leaf, enabled = true, speed = speed, bezier = curve, style = style })
end

-- Windows: pop in from 90% + fade (~280ms); close quicker with a slight shrink (~200ms)
anim("windowsIn",   2.8, "easeOutQuint",   "popin 90%")
anim("windowsOut",  2.0, "easeInOutCubic", "popin 95%")
anim("windowsMove", 3.0, "easeOutQuint")              -- tiles glide, never jump

-- Fades (~150-200ms)
anim("fadeIn",      2.0, "easeOutQuint")
anim("fadeOut",     1.8, "easeInOutCubic")
anim("fadeSwitch",  1.8, "quick")
anim("fadeShadow",  1.8, "quick")
anim("fadeDim",     1.8, "quick")

-- Borders: smooth color change. The gradient angle eases once on focus change
-- (a constant "loop" would redraw the screen non-stop and keep the GPU awake).
anim("border",      2.0, "easeOutQuint")
anim("borderangle", 8.0, "easeInOutCubic", "once")

-- Layers (rofi etc.): fade + small pop-in. Quickshell layers opt out (rules.lua).
anim("layersIn",      2.2, "easeOutQuint",   "popin 92%")
anim("layersOut",     1.6, "easeInOutCubic", "fade")
anim("fadeLayersIn",  2.0, "easeOutQuint")
anim("fadeLayersOut", 1.6, "easeInOutCubic")

-- Workspaces: horizontal slide + fade (~350ms); special workspace slides vertically
anim("workspaces",       3.5, "easeOutQuint", "slidefade 20%")
anim("specialWorkspace", 3.0, "easeOutQuint", "slidevert")

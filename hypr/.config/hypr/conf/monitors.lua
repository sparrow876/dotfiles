-- Built-in panel: 1920x1080, max refresh 144Hz (checked with `hyprctl monitors`).
-- The panel reports no VRR support, so VRR stays off (vrr = 0).
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@144",
    position = "0x0",
    scale    = 1,
    vrr      = 0,
})

-- Anything else (HDMI on the RTX 3050): highest refresh rate, placed to the right.
hl.monitor({
    output   = "",
    mode     = "highrr",
    position = "auto-right",
    scale    = "auto",
})

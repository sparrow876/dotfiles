-- Gaps, borders, rounding, blur, layout and misc behavior.
local c = require("conf.colors")

hl.config({
    general = {
        gaps_in     = c.gaps_in,
        gaps_out    = c.gaps_out,
        border_size = c.border_size,
        col = {
            -- light blue -> ice gradient on the focused window
            active_border   = { colors = { c.rgba("lightblue"), c.rgba("ice") }, angle = 45 },
            inactive_border = c.rgba("overlay", "cc"),
        },
        resize_on_border = true,
        layout           = "dwindle",
        allow_tearing    = true,   -- only used by windows with the `immediate` rule (games.lua)
    },

    decoration = {
        rounding       = c.rounding,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = 0x55000000,   -- always a dark shadow (also in light themes)
        },

        -- Frosted glass: only surfaces that are themselves translucent get blurred
        -- (kitty, Quickshell panels, rofi).
        blur = {
            enabled  = true,
            size     = 8,
            passes   = 3,
            noise    = 0.02,
            vibrancy = 0.17,
            popups   = true,
            new_optimizations = true,
        },
    },

    dwindle = {
        preserve_split = true,    -- a split keeps its direction when windows close
        force_split    = 2,       -- new window goes right/bottom of the focused one
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = c.argb("base"),  -- no white/black flash behind windows
        focus_on_activate        = false,   -- apps can't steal focus by themselves
        allow_session_lock_restore = true,  -- recover if the lock screen crashes
        animate_manual_resizes   = true,    -- tiles glide when resized
        animate_mouse_windowdragging = false,
        vrr                      = 0,       -- panel has no VRR (see monitors.lua)
    },

    binds = {
        workspace_back_and_forth = false,
    },

    cursor = {
        inactive_timeout = 5,  -- hide the cursor after 5s without movement
    },
})

-- Gaps, borders, rounding, blur, layout and misc behavior.
local c = require("conf.colors")

-- Layout mode (scripts/layout-mode.sh, bar button, ALT + G): "spaced" (gaps,
-- rounded windows, shadows) or "compact" (i3-style: no gaps, square windows,
-- no shadows). Read from ~/.local/state/rice/layout on every config load.
local function layout_mode()
    local dir = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
    local f = io.open(dir .. "/rice/layout", "r")
    if not f then return "spaced" end
    local mode = f:read("*l")
    f:close()
    return mode == "compact" and "compact" or "spaced"
end
local compact = layout_mode() == "compact"

hl.config({
    general = {
        gaps_in     = compact and 0 or c.gaps_in,
        gaps_out    = compact and 0 or c.gaps_out,
        border_size = c.border_size,
        col = {
            -- Focused window: a soft Blue Ice "aurora" (light blue -> ice ->
            -- cyan -> a hint of lavender -> back), slightly see-through so it
            -- never glares. It drifts round once when a window opens or gets
            -- focus (borderangle in animations.lua), still otherwise.
            active_border   = {
                colors = {
                    c.rgba("lightblue", "ee"), c.rgba("ice", "d9"), c.rgba("cyan", "d9"),
                    c.rgba("lavender", "b3"), c.rgba("lightblue", "ee"),
                },
                angle = 45,
            },
            -- Other windows: a quiet dark-blue gradient
            inactive_border = { colors = { c.rgba("overlay", "cc"), c.rgba("blue", "80") }, angle = 45 },
        },
        resize_on_border = true,
        layout           = "dwindle",
        allow_tearing    = true,   -- only used by windows with the `immediate` rule (games.lua)
    },

    decoration = {
        rounding       = compact and 0 or c.rounding,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        -- Unfocused windows slightly dimmed so the focused one stands out
        -- (PiP and call pop-outs are exempt: no_dim in rules.lua)
        dim_inactive     = true,
        dim_strength     = 0.07,

        shadow = {
            enabled      = not compact,   -- shadows on touching windows just look muddy
            range        = 12,
            render_power = 3,
            color        = 0x55000000,   -- always a dark shadow
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

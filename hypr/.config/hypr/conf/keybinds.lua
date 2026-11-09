-- Keybinds. Modifier is ALT; SUPER is only used for the lock screen.
-- Every bind has a description "Category: Action". The cheat sheet (ALT + /) and
-- the README keybind table are generated from these (`hyprctl binds -j`).
--
-- Binds for features that don't exist yet are added in the build step that
-- creates them (launcher theme, dropdown terminal, panels, capture tools, lock).

local mod = "ALT"

-- bind("ALT + Q", dispatcher, "Windows: Close window", { optional flags })
local function bind(keys, dispatcher, description, opts)
    opts = opts or {}
    opts.description = description
    return hl.bind(keys, dispatcher, opts)
end
local exec = hl.dsp.exec_cmd

-- ---------------------------------------------------------------------------
-- Apps
bind(mod .. " + Return", exec("kitty"),               "Apps: Terminal (kitty)")
bind(mod .. " + D",      exec("rofi -show drun"),     "Apps: App launcher")
bind(mod .. " + E",      exec("nautilus --new-window"), "Apps: Files (Nautilus)")

-- ---------------------------------------------------------------------------
-- Windows
bind(mod .. " + Q",           hl.dsp.window.close(),                           "Windows: Close window")
bind(mod .. " + F",           hl.dsp.window.fullscreen({ action = "toggle" }), "Windows: Toggle fullscreen")
bind(mod .. " + V",           hl.dsp.window.float({ action = "toggle" }),      "Windows: Toggle floating")
bind(mod .. " + Tab",         hl.dsp.window.cycle_next(),                      "Windows: Next window on workspace")
bind(mod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }),      "Windows: Previous window on workspace")

local directions = {
    { vim = "H", arrow = "left",  dir = "left"  },
    { vim = "J", arrow = "down",  dir = "down"  },
    { vim = "K", arrow = "up",    dir = "up"    },
    { vim = "L", arrow = "right", dir = "right" },
}
for _, d in ipairs(directions) do
    bind(mod .. " + " .. d.vim,   hl.dsp.focus({ direction = d.dir }), "Windows: Focus " .. d.dir)
    bind(mod .. " + " .. d.arrow, hl.dsp.focus({ direction = d.dir }), "Windows: Focus " .. d.dir)
    bind(mod .. " + SHIFT + " .. d.vim,   hl.dsp.window.move({ direction = d.dir }), "Windows: Move window " .. d.dir)
    bind(mod .. " + SHIFT + " .. d.arrow, hl.dsp.window.move({ direction = d.dir }), "Windows: Move window " .. d.dir)
end

-- Mouse: ALT + left-drag moves, ALT + right-drag resizes
bind(mod .. " + mouse:272", hl.dsp.window.drag(),   "Windows: Move with mouse (drag)",   { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Windows: Resize with mouse (drag)", { mouse = true })

-- ---------------------------------------------------------------------------
-- Workspaces 1-6
for i = 1, 6 do
    bind(mod .. " + " .. i,             hl.dsp.focus({ workspace = i }),       "Workspaces: Go to workspace " .. i)
    bind(mod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i }), "Workspaces: Move window to workspace " .. i)
end

-- ---------------------------------------------------------------------------
-- Media keys (work on the lock screen too)
local locked_repeat = { locked = true, repeating = true }
bind("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), "Media: Volume up",   locked_repeat)
bind("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),        "Media: Volume down", locked_repeat)
bind("XF86AudioMute",        exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),       "Media: Mute",        { locked = true })
bind("XF86AudioMicMute",     exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),     "Media: Mute microphone", { locked = true })
bind("XF86AudioPlay",        exec("playerctl play-pause"), "Media: Play / pause",  { locked = true })
bind("XF86AudioPause",       exec("playerctl play-pause"), "Media: Play / pause",  { locked = true })
bind("XF86AudioNext",        exec("playerctl next"),       "Media: Next track",    { locked = true })
bind("XF86AudioPrev",        exec("playerctl previous"),   "Media: Previous track", { locked = true })

-- Screen brightness (no keyboard backlight is exposed on this laptop)
bind("XF86MonBrightnessUp",   exec("brightnessctl -n2 set 5%+"), "Media: Brightness up",   locked_repeat)
bind("XF86MonBrightnessDown", exec("brightnessctl -n2 set 5%-"), "Media: Brightness down", locked_repeat)

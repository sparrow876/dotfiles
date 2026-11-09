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
bind(mod .. " + C",         exec(os.getenv("HOME") .. "/dotfiles/scripts/clipboard.sh"), "Apps: Clipboard history")
bind(mod .. " + SHIFT + E", exec(os.getenv("HOME") .. "/dotfiles/scripts/emoji.sh"),     "Apps: Emoji picker")
bind(mod .. " + E",      exec("nautilus --new-window"), "Apps: Files (Nautilus)")

-- Dropdown terminal: a kitty (class "dropterm") living on the special workspace
-- "dropterm". Launched on first use; afterwards ALT + ` just shows/hides it and the
-- session keeps running. Placement/size: rules.lua. DROPTERM=1 skips fastfetch.
local function dropterm_exists()
    for _, w in ipairs(hl.get_windows()) do
        if w.class == "dropterm" then return true end
    end
    return false
end
bind(mod .. " + grave", function()
    if dropterm_exists() then
        hl.dispatch(hl.dsp.workspace.toggle_special("dropterm"))
        return
    end
    hl.exec_cmd("kitty --class dropterm -o env=DROPTERM=1")
    local shown = hl.get_active_special_workspace()
    if not (shown and shown.name == "special:dropterm") then
        hl.dispatch(hl.dsp.workspace.toggle_special("dropterm"))
    end
end, "Apps: Dropdown terminal")

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
-- Capture: screenshots, color picker, OCR, screen recording
local scripts = os.getenv("HOME") .. "/dotfiles/scripts/"
bind("Print",                 exec(scripts .. "screenshot.sh region"), "Capture: Screenshot of a region")
bind(mod .. " + SHIFT + S",   exec(scripts .. "screenshot.sh region"), "Capture: Screenshot of a region (alternative)")
bind("SHIFT + Print",         exec(scripts .. "screenshot.sh full"),   "Capture: Screenshot of the whole screen")
bind(mod .. " + Print",       exec(scripts .. "screenshot.sh window"), "Capture: Screenshot of the active window")
bind(mod .. " + SHIFT + C",   exec(scripts .. "colorpick.sh"),         "Capture: Pick a color (hex copied)")
bind(mod .. " + O",           exec(scripts .. "ocr.sh"),               "Capture: Copy text from a screen region (OCR)")
bind(mod .. " + R",           exec("qs ipc call recorder toggleFull"),   "Capture: Start/stop screen recording")
bind(mod .. " + SHIFT + R",   exec("qs ipc call recorder toggleRegion"), "Capture: Start/stop recording a region")
bind(mod .. " + CTRL + R",    exec("qs ipc call recorder replay"),       "Capture: Replay mode on / save last 60 s")

-- ---------------------------------------------------------------------------
-- System
bind(mod .. " + I", exec("qs ipc call idle toggle"), "System: Toggle idle inhibitor (stay awake)")
bind(mod .. " + N", exec("qs ipc call popups toggle notifications"), "System: Notification center")
bind(mod .. " + S", exec("qs ipc call panel toggle"), "System: System stats panel")
bind(mod .. " + W", exec("qs ipc call wallpaper toggle"), "System: Wallpaper selector")
bind(mod .. " + Escape", exec("qs ipc call powermenu toggle"), "System: Power menu")
-- SUPER is used only for locking
bind("SUPER + L", exec(os.getenv("HOME") .. "/dotfiles/scripts/lock.sh"), "System: Lock screen")

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

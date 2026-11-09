-- Hyprland config entry point (Hyprland 0.57+ uses Lua; the old hyprland.conf
-- format is not used). This file only loads the pieces in conf/, in order.
-- `require("conf.x")` loads conf/x.lua next to this file.
--
-- Check for errors without restarting:   Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
-- Apply changes to the running session:  hyprctl reload

require("conf.env")         -- environment variables (toolkits, cursor)
require("conf.monitors")    -- 1920x1080 @ 144Hz panel
require("conf.input")       -- keyboard, touchpad, gestures
require("conf.look")        -- gaps, borders, blur, rounding, layout
require("conf.animations")  -- curves + animation speeds
require("conf.rules")       -- window, layer and workspace rules
require("conf.games")       -- Steam/gamescope rules (tearing, no effects)
require("conf.keybinds")    -- every bind has a "Category: action" description
require("conf.autostart")   -- background services started with the session

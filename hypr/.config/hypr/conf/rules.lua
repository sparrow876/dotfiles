-- Window, layer and workspace rules.
-- Find a window's class/title with:  hyprctl clients
-- Find a layer's namespace with:     hyprctl layers

-- ---------------------------------------------------------------------------
-- Workspaces 1-6 always exist (the bar shows 一 二 三 四 五 六)
for i = 1, 6 do
    hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

-- ---------------------------------------------------------------------------
-- All windows
hl.window_rule({
    name  = "suppress-maximize",            -- apps can't maximize themselves
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "idle-inhibit-fullscreen",      -- videos and games never trigger idle
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name  = "fix-xwayland-drags",           -- from Hyprland's default config
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- ---------------------------------------------------------------------------
-- Dialogs: float. Hyprland already opens a dialog centered over its parent
-- window (checked in the 0.57 source), so no `center` here.
hl.window_rule({
    name  = "float-modal-dialogs",
    match = { modal = true },
    float = true,
})

-- Utility windows: float, centered, ~55% of the screen
local centered_apps = {
    "xdg-desktop-portal-gtk",      -- file picker (Open / Save)
    "org.pulseaudio.pavucontrol",
    "nm-connection-editor",
    "org.blueman.Manager",
    "protonvpn-app",
    "org.localsend.localsend_app",
    ".*polkit.*",                  -- password prompts (hyprpolkitagent)
    "hyprland-share-picker",       -- screen-share picker
}
hl.window_rule({
    name   = "float-center-utilities",
    match  = { class = "^(" .. table.concat(centered_apps, "|") .. ")$" },
    float  = true,
    size   = { "monitor_w*0.55", "monitor_h*0.55" },
    center = true,
})

-- Bluetooth PIN entry dialog (blueman-applet, the pairing agent): small, centered
hl.window_rule({
    name   = "float-bluetooth-pin",
    match  = { class = "^(org.blueman.Applet|blueman-applet)$" },
    float  = true,
    center = true,
})

-- Enterprise Wi-Fi setup (Wi-Fi menu → Set up…, scripts/wifi-enterprise.sh)
hl.window_rule({
    name   = "float-center-wifi-setup",
    match  = { class = "^wifi-setup$" },
    float  = true,
    size   = { "monitor_w*0.42", "monitor_h*0.4" },
    center = true,
})

hl.window_rule({
    name   = "float-center-steam-dialogs",
    match  = { class = "^steam$", title = "^(Friends List|Steam Settings)$" },
    float  = true,
    size   = { "monitor_w*0.5", "monitor_h*0.55" },
    center = true,
})

-- ---------------------------------------------------------------------------
-- Dropdown terminal (ALT + `): top-center under the bar, 60% x 45%.
-- The bar is 44px tall, 8px from the top, + 12px gap -> window starts 64px down.
hl.window_rule({
    name      = "dropterm",
    match     = { class = "^dropterm$" },
    workspace = "special:dropterm",
    float     = true,
    size      = { "monitor_w*0.6", "monitor_h*0.45" },
    move      = { "(monitor_w-window_w)/2", "64" },
})

-- ---------------------------------------------------------------------------
-- Picture-in-Picture (Zen): small, pinned, bottom-right with a 24px margin
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin   = true,
    keep_aspect_ratio = true,
    size  = { "monitor_w*0.25", "monitor_h*0.25" },
    move  = { "monitor_w-window_w-24", "monitor_h-window_h-24" },
})

-- ---------------------------------------------------------------------------
-- Work & chat apps (Teams, Vesktop/Discord)
-- No focus stealing: misc.focus_on_activate = false (look.lua) already stops
-- their notifications from raising/switching windows; clicking a notification
-- focuses the app on purpose (services/Notifications.qml).
-- Call pop-outs / mini windows: small, pinned, bottom-right like PiP.
-- (Title patterns to confirm while testing calls; see system/APPS.md.)
hl.window_rule({
    name  = "call-popouts",
    match = { class = "^(teams-for-linux|vesktop)$", title = "(?i)^(.*pop-?out.*|.*mini.?view.*|picture.in.picture)$" },
    float = true,
    pin   = true,
    size  = { "monitor_w*0.25", "monitor_h*0.25" },
    move  = { "monitor_w-window_w-24", "monitor_h-window_h-24" },
})

-- ---------------------------------------------------------------------------
-- Layers
-- Quickshell surfaces animate themselves and get frosted-glass blur.
-- Every Quickshell window in this repo uses a namespace starting with "quickshell".
hl.layer_rule({
    name  = "quickshell",
    match = { namespace = "^quickshell.*" },
    no_anim      = true,
    blur         = true,
    ignore_alpha = 0.1,   -- don't blur fully transparent parts (shadows, gaps)
    blur_popups  = true,  -- tooltips and tray menus
})

hl.layer_rule({
    name  = "rofi",
    match = { namespace = "^rofi$" },
    blur         = true,
    ignore_alpha = 0.1,
})

-- Started once when Hyprland starts. More services are added in later build
-- steps (bar, wallpaper, clipboard, idle, ...).
--
-- Already handled without anything here:
--   xdg-desktop-portal(-hyprland/-gtk): started on demand over D-Bus
--   gnome-keyring: socket-activated user service (unlocked at login from step 14)
--   PipeWire / WirePlumber: user services

hl.on("hyprland.start", function()
    -- Password prompts for apps that need admin rights (polkit agent)
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")

    -- Wallpaper daemon (awww), then the remembered wallpaper
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd(os.getenv("HOME") .. "/dotfiles/scripts/wallpaper.sh restore")

    -- Bar, widgets and (later) notifications: ~/.config/quickshell/shell.qml.
    -- Quickshell reloads itself when a .qml file changes.
    hl.exec_cmd("qs")

    -- Clipboard history (ALT + C): record text and images, keep 200 entries,
    -- and keep copied content alive after the source app closes
    hl.exec_cmd("wl-paste --type text --watch cliphist -max-items 200 store")
    hl.exec_cmd("wl-paste --type image --watch cliphist -max-items 200 store")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
end)

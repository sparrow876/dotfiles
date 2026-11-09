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
end)

-- Environment variables for apps started by Hyprland.
--
-- GPU: Hyprland renders on the Intel iGPU. Aquamarine (Hyprland's backend) puts
-- the GPU with boot_vga=1 first and prefers the GPU driving the built-in panel;
-- on this laptop both are the iGPU, so no AQ_DRM_DEVICES is needed. The RTX 3050
-- is still attached as a secondary GPU (it drives the HDMI port).
-- Do NOT set the NVIDIA-only variables (GBM_BACKEND, __GLX_VENDOR_LIBRARY_NAME,
-- LIBVA_DRIVER_NAME=nvidia) here: they would push every app onto the RTX 3050.
-- Apps that should use NVIDIA are started with `prime-run`.

-- Cursor
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Toolkits: prefer Wayland, fall back to X11
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("CLUTTER_BACKEND", "wayland")
-- SDL_VIDEODRIVER=wayland is deliberately NOT set: it breaks some games/Proton.

-- Qt look (qt6ct/qt5ct themes are set up in build step 16)
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- GTK4 apps (Nautilus, Loupe, ...): use the OpenGL renderer. The default Vulkan
-- renderer enumerates every GPU at startup, which wakes the sleeping RTX 3050 and
-- adds ~1.6 s to every launch (measured: Nautilus 2.3 s -> 0.64 s).
-- Also set in systemd/.config/environment.d for D-Bus-started apps.
hl.env("GSK_RENDERER", "ngl")

-- Electron apps (Teams, Discord, Claude, ...) run as native Wayland -> sharp text
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

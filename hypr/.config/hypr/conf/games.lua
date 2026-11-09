-- Games: Steam games (class steam_app_<id>) and anything in gamescope.
-- No blur/rounding/animations/shadows, fullscreen, and tearing ("immediate")
-- for lower latency. Tearing only kicks in while the game is fullscreen and is
-- the only thing on screen (`hyprctl monitors` shows tearingBlockedBy otherwise).
-- Note: games render on the RTX 3050 but are shown through the Intel iGPU, so
-- whether tearing actually applies is verified in build step 19.
-- Auto-DND while a game is fullscreen is handled by Quickshell (step 7).

local game = "^(steam_app_.*|gamescope)$"

hl.window_rule({
    name  = "games",
    match = { class = game },
    fullscreen  = true,
    immediate   = true,
    no_blur     = true,
    no_anim     = true,
    no_shadow   = true,
    rounding    = 0,
    border_size = 0,
})

-- Anything that tells Hyprland it is a game (content-type protocol) also tears.
hl.window_rule({
    name  = "game-content",
    match = { content = "game" },
    immediate = true,
})

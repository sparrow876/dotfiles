-- Games: Steam games (class steam_app_<id>) and anything in gamescope.
-- No blur/rounding/animations/shadows, fullscreen, and tearing ("immediate")
-- for lower latency. Tearing only kicks in while the game is fullscreen and is
-- the only thing on screen (`hyprctl monitors` shows tearingBlockedBy otherwise).
-- Verified 2026-11-09: tearing works with this hybrid setup (rendered on the
-- RTX 3050 via prime-run, shown through the Intel iGPU): `hyprctl monitors -j`
-- showed activelyTearing = true for a fullscreen immediate-mode window.
-- The laptop panel has no VRR, so there is no VRR rule.
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

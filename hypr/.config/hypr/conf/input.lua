-- Keyboard, mouse and touchpad.
hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,       -- focus follows the mouse
        sensitivity  = 0,       -- -1.0 .. 1.0, 0 = no change

        touchpad = {
            tap_to_click         = true,
            natural_scroll       = false,   -- "normal" scrolling (user choice, 2026-11-09)
            disable_while_typing = true,
        },
    },

    gestures = {
        workspace_swipe_distance = 300,   -- px of swipe for a full workspace change
        workspace_swipe_cancel_ratio = 0.3,
        -- false = non-natural, like the touchpad scrolling above: swipe right
        -- -> next workspace. (true, Hyprland's default, moves the workspaces
        -- with the fingers.) User choice, 2026-11-13.
        workspace_swipe_invert = false,
    },
})

-- 3-finger swipe left/right switches workspace
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- 3-finger swipe up: window overview (GNOME-style, quickshell overview/);
-- swipe down closes it. A plain function fires once when the swipe ends.
hl.gesture({
    fingers   = 3,
    direction = "up",
    action    = function() hl.exec_cmd("qs ipc call overview open") end,
})
hl.gesture({
    fingers   = 3,
    direction = "down",
    action    = function() hl.exec_cmd("qs ipc call overview close") end,
})

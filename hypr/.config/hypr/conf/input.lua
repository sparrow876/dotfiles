-- Keyboard, mouse and touchpad.
hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,       -- focus follows the mouse
        sensitivity  = 0,       -- -1.0 .. 1.0, 0 = no change

        touchpad = {
            tap_to_click         = true,
            natural_scroll       = true,
            disable_while_typing = true,
        },
    },

    gestures = {
        workspace_swipe_distance = 300,   -- px of swipe for a full workspace change
        workspace_swipe_cancel_ratio = 0.3,
    },
})

-- 3-finger swipe left/right switches workspace
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

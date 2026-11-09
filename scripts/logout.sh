#!/usr/bin/env bash
# End the Hyprland session (back to the TTY / login screen).
# hyprshutdown closes apps gracefully first (no "restore session?" prompts);
# without it, exit Hyprland directly.
if command -v hyprshutdown >/dev/null; then
  exec hyprshutdown
fi
exec hyprctl dispatch 'hl.dsp.exit()'

#!/usr/bin/env bash
# Lock the screen. Used by SUPER + L, the power menu and (step 14) hypridle.
# The lock screen is qylock's Quickshell lock (installed in build step 14).
lock="$HOME/.local/share/quickshell-lockscreen/lock.sh"
if [[ -x $lock ]]; then
  exec "$lock" "$@"
fi
notify-send -a "Lock screen" -i system-lock-screen "Lock screen not set up yet" \
  "The qylock lock screen is installed in build step 14."
exit 1

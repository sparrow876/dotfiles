#!/usr/bin/env bash
# Lock the screen. Used by SUPER + L, the power menu, hypridle (5 min idle) and
# before suspend. The lock screen is qylock's Quickshell lock ("winter" theme),
# installed by running ~/.local/src/qylock/quickshell.sh (system/ROOT-STEPS.md 10).
lock="$HOME/.local/share/quickshell-lockscreen/lock.sh"
# Already locked? Don't start a second lock screen.
# (anchored to the start of the command line, so e.g. `nvim .../lock_shell.qml`
# doesn't count as "locked")
pgrep -f '^([^ ]*/)?(quickshell|qs) .*quickshell-lockscreen/lock_shell\.qml' >/dev/null && exit 0
if [[ -x $lock ]]; then
  exec "$lock" "$@"
fi
notify-send -a "Lock screen" -i system-lock-screen "Lock screen not set up yet" \
  "Run ~/.local/src/qylock/quickshell.sh (see system/ROOT-STEPS.md, section 10)."
exit 1

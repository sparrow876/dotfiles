#!/usr/bin/env bash
# Lock the screen. Used by SUPER + L, the power menu, hypridle (5 min idle) and
# before suspend.
# The lock screen is qylock's Quickshell session lock (lock_shell.qml + its
# PAM shim, installed by ~/.local/src/qylock/quickshell.sh, ROOT-STEPS 10,
# patched by lockscreen/apply-patches.sh) showing a theme:
#   default             this repo's lockscreen/themes/strawberry-milk
#   lock.sh <name>      a theme from this repo's lockscreen/themes/, else one of
#                       qylock's (~/.local/src/qylock/themes, e.g. winter)
#   LOCK_THEME=<name>   same, from the environment
# (qylock's own lock.sh is not used: it always picks "winter".)
qs_lock="$HOME/.local/share/quickshell-lockscreen"
repo_themes="$HOME/dotfiles/lockscreen/themes"
theme="${1:-${LOCK_THEME:-strawberry-milk}}"

# Already locked? Don't start a second lock screen.
# (anchored to the start of the command line, so e.g. `nvim .../lock_shell.qml`
# doesn't count as "locked")
pgrep -f '^([^ ]*/)?(quickshell|qs) .*quickshell-lockscreen/lock_shell\.qml' >/dev/null && exit 0

if [[ ! -f $qs_lock/lock_shell.qml ]]; then
  notify-send -a "Lock screen" -i system-lock-screen "Lock screen not set up yet" \
    "Run ~/.local/src/qylock/quickshell.sh (see system/ROOT-STEPS.md, section 10)."
  exit 1
fi

if [[ -f $repo_themes/$theme/Main.qml ]]; then
  theme_path="$repo_themes/$theme"
elif [[ -f $qs_lock/themes_link/$theme/Main.qml ]]; then
  theme_path="$qs_lock/themes_link/$theme"
else
  theme="strawberry-milk"; theme_path="$repo_themes/$theme"
fi

# The idle screen (4 min) would keep animating behind the lock screen all
# night: hide it once the lock is up (brightness comes back on input)
( sleep 2; qs ipc call idlescreen leave ) >/dev/null 2>&1 &
disown

# Same environment qylock's lock.sh sets up, with our theme
export QML2_IMPORT_PATH="$qs_lock/imports${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export QML_XHR_ALLOW_FILE_READ=1          # the shim reads theme.conf
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
export QS_THEME="$theme" QS_THEME_PATH="$theme_path"
exec quickshell -p "$qs_lock/lock_shell.qml"

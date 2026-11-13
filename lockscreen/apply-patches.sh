#!/usr/bin/env bash
# Apply this repo's fixes to qylock (lock screen), see patches/*.patch.
#   lockscreen/apply-patches.sh            apply (safe to re-run)
#   lockscreen/apply-patches.sh --revert   undo
#
# What it changes (all as your user, no sudo):
#  1. the pinned qylock clone ~/.local/src/qylock (git apply; the lock screen's
#     themes are read from there through a symlink)
#  2. the installed lock screen ~/.local/share/quickshell-lockscreen: its copy of
#     shim/SddmShim.qml is refreshed from the clone (qylock's quickshell.sh
#     copied it there; re-running quickshell.sh overwrites it, so run this again
#     afterwards). The original is kept as SddmShim.qml.orig.
# A lock screen that is already showing keeps the old code until it closes.
# SDDM's login screen (/usr/share/sddm/themes/winter) is not touched.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLONE="$HOME/.local/src/qylock"
INSTALLED="$HOME/.local/share/quickshell-lockscreen"
SHIM=quickshell-lockscreen/shim/SddmShim.qml

[[ $EUID -ne 0 ]] || { echo "run as your normal user (not with sudo)"; exit 1; }
[[ -d $CLONE/.git ]] || { echo "no qylock clone at ${CLONE/#$HOME/\~} (install.sh --only clones)"; exit 1; }

revert=0
[[ ${1:-} == --revert ]] && revert=1

for p in "$REPO"/lockscreen/patches/*.patch; do
  name=$(basename "$p")
  if ((revert)); then
    if git -C "$CLONE" apply --check -R -p1 "$p" 2>/dev/null; then
      git -C "$CLONE" apply -R -p1 "$p" && echo "reverted  $name"
    else
      echo "skip      $name (not applied)"
    fi
  elif git -C "$CLONE" apply --check -R -p1 "$p" 2>/dev/null; then
    echo "ok        $name (already applied)"
  elif git -C "$CLONE" apply --check -p1 "$p" 2>/dev/null; then
    git -C "$CLONE" apply -p1 "$p" && echo "applied   $name"
  else
    echo "FAILED    $name doesn't fit this qylock version (pinned commit changed?)" >&2
    exit 1
  fi
done

# Refresh the installed lock screen's copy of the shim
if [[ -f $INSTALLED/shim/SddmShim.qml ]]; then
  if ((revert)) && [[ -f $INSTALLED/shim/SddmShim.qml.orig ]]; then
    mv -f "$INSTALLED/shim/SddmShim.qml.orig" "$INSTALLED/shim/SddmShim.qml"
    echo "restored  installed shim"
  elif ! cmp -s "$CLONE/$SHIM" "$INSTALLED/shim/SddmShim.qml"; then
    [[ -f $INSTALLED/shim/SddmShim.qml.orig ]] || cp "$INSTALLED/shim/SddmShim.qml" "$INSTALLED/shim/SddmShim.qml.orig"
    cp "$CLONE/$SHIM" "$INSTALLED/shim/SddmShim.qml"
    echo "updated   installed shim (${INSTALLED/#$HOME/\~}/shim)"
  else
    echo "ok        installed shim up to date"
  fi
else
  echo "note      lock screen not installed yet (qylock's quickshell.sh); run this again after it"
fi
echo "Done. Test: SUPER + L, press Enter with an empty box, then type your password."

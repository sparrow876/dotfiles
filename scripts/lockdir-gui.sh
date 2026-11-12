#!/usr/bin/env bash
# Password dialogs around lockdir.sh, used by Nautilus's right-click menu
# (nautilus/…/extensions/lock_folder.py):
#   lockdir-gui.sh lock FOLDER          ask for a new password (twice), lock it
#   lockdir-gui.sh unlock FILE.locked   ask for the password, unlock it
# The password goes to lockdir.sh through a pipe (never on a command line).
# Errors show as a dialog, success as a notification.
set -uo pipefail

LOCKDIR="$(dirname "$(realpath "$0")")/lockdir.sh"
TITLE="Lock folder"
mode=${1:-} target=${2:-}
[[ ($mode == lock || $mode == unlock) && -n $target ]] || {
  echo "usage: lockdir-gui.sh lock FOLDER | unlock FILE.locked" >&2; exit 2; }
name=$(basename -- "$target")

error() { zenity --error --title "$TITLE" --width 380 --text "$1" 2>/dev/null; }
esc() { local s=${1//&/&amp;}; s=${s//</&lt;}; printf '%s' "${s//>/&gt;}"; }   # for zenity's markup

# run "progress text" PASSWORD ARGS...: lockdir.sh with a pulsing progress
# dialog; leaves its output in $out and returns its exit status
run() {
  local text=$1 pw=$2 log status
  shift 2
  log=$(mktemp) status=$(mktemp)
  ( printf '%s\n' "$pw" | "$LOCKDIR" --password-stdin "$@" >"$log" 2>&1; echo $? >"$status" ) |
    zenity --progress --pulsate --auto-close --no-cancel --title "$TITLE" \
      --width 380 --text "$text" 2>/dev/null
  out=$(<"$log"); local rc; rc=$(<"$status")
  rm -f "$log" "$status"
  return "${rc:-1}"
}

if [[ $mode == lock ]]; then
  [[ -d $target ]] || { error "Not a folder: $(esc "$name")"; exit 1; }
  while :; do
    form=$(zenity --forms --title "$TITLE" --width 420 --separator=$'\x1f' \
      --text "Lock “$(esc "$name")” with a password.
The folder becomes one encrypted file, $(esc "$name").locked.
<b>Forget the password and the files are gone for good.</b>" \
      --add-password "Password" --add-password "Repeat password" 2>/dev/null) || exit 0
    pw=${form%%$'\x1f'*} again=${form#*$'\x1f'}
    if [[ -z $pw ]]; then error "The password can't be empty."; continue; fi
    if [[ $pw != "$again" ]]; then error "The passwords don't match. Try again."; continue; fi
    break
  done
  if run "Locking “$(esc "$name")”…" "$pw" "$target"; then
    notify-send -a "$TITLE" -i changes-prevent "Locked $name" \
      "Now $name.locked. Right-click it → Unlock to open it again."
  else
    error "Couldn't lock “$(esc "$name")”:
$(esc "$(grep '^lockdir:' <<<"$out" | tail -1 | sed 's/^lockdir: //')")"
    exit 1
  fi
else
  [[ -f $target && $target == *.locked ]] || { error "Not a .locked file: $(esc "$name")"; exit 1; }
  while :; do
    pw=$(zenity --password --title "Unlock “$name”" 2>/dev/null) || exit 0
    [[ -n $pw ]] || continue
    if run "Unlocking “$(esc "$name")”…" "$pw" --unlock "$target"; then
      notify-send -a "$TITLE" -i changes-allow "Unlocked ${name%.locked}" \
        "The folder is back. Right-click it → Lock with Password when you're done."
      exit 0
    fi
    msg=$(grep '^lockdir:' <<<"$out" | tail -1 | sed 's/^lockdir: //')
    if [[ $msg == wrong\ password* ]]; then
      error "Wrong password. Try again."
    else
      error "Couldn't unlock “$(esc "$name")”:
$(esc "$msg")"
      exit 1
    fi
  done
fi

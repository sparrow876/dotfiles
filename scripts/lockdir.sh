#!/usr/bin/env bash
# Password-protect a folder: pack it into one encrypted file, then remove the
# readable folder. Unlock gives the folder back exactly as it was.
#
#   lockdir FOLDER              ->  FOLDER.locked   (asks for a new password twice)
#   unlockdir FILE.locked       ->  FOLDER          (asks for the password)
#   (= lockdir --unlock FILE.locked; both on PATH via ~/.local/bin)
#   --password-stdin            read the password from stdin (one line, no
#                               repeat), for scripts/lockdir-gui.sh (Nautilus)
#
# How: tar + zstd packs the folder, GnuPG encrypts it with the password
# (AES-256, slow key derivation so guessing passwords is expensive). The
# password is never cached by gpg-agent and never appears in the process list.
# Before the original is removed, the locked file is decrypted again and
# compared with the folder byte for byte; if anything differs, nothing is
# removed. Forget the password and the data is gone: there's no recovery.
#
# Limits (worth knowing):
# - /home has snapper snapshots: older snapshots still contain the readable
#   folder until they expire (see `snapper -c home list`).
# - Removing files on an SSD/btrfs doesn't overwrite them, so the old data may
#   stay recoverable on the disk for a while. Fine against people opening your
#   files; not a defense against forensic disk analysis.
set -Eeuo pipefail

die() { printf 'lockdir: %s\n' "$*" >&2; exit 1; }
# Any other failure (tar, gpg, mv) says where, so the Nautilus dialog isn't blank
trap 'die "stopped by an error at line $LINENO"' ERR
usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

PASSWORD_STDIN=0
tmp=""   # temp file/folder, removed on exit (global: the EXIT trap runs after the function returns)
GPG=(gpg --quiet --batch --no-symkey-cache --pinentry-mode loopback --passphrase-fd 3)

ask_password() {   # ask_password VAR [confirm]
  local -n _pw=$1
  local again
  if ((PASSWORD_STDIN)); then
    IFS= read -r _pw || true
    [[ -n $_pw ]] || die "empty password"
    return
  fi
  [[ -t 0 ]] || die "needs a terminal to ask for the password"
  IFS= read -rs -p "Password: " _pw; echo >&2
  [[ -n $_pw ]] || die "empty password"
  if [[ ${2:-} == confirm ]]; then
    IFS= read -rs -p "Repeat password: " again; echo >&2
    [[ $_pw == "$again" ]] || die "passwords don't match"
  fi
}

lock() {
  local dir parent name out pw start changed
  [[ -d $1 && ! -L $1 ]] || die "not a folder: $1"
  dir="$(realpath -- "$1")"
  [[ $dir != / && $dir != "$HOME" ]] || die "refusing to lock $dir"
  # Mount points and btrfs subvolumes (Downloads, Recordings, .cache are their
  # own subvolumes) can be emptied but not removed or replaced: refuse them.
  ! mountpoint -q -- "$dir" || die "refusing: ${dir/#$HOME/\~} is a mount point; lock a folder inside it"
  [[ $(stat -f -c %T -- "$dir") != btrfs || $(stat -c %i -- "$dir") != 256 ]] ||
    die "refusing: ${dir/#$HOME/\~} is a btrfs subvolume; lock a folder inside it"
  parent="$(dirname -- "$dir")" name="$(basename -- "$dir")"
  out="$parent/$name.locked"
  [[ ! -e $out ]] || die "already exists: $out"
  [[ -w $parent ]] || die "can't write in $parent"

  echo "Locking ${dir/#$HOME/\~} ($(du -sh -- "$dir" | cut -f1))"
  ask_password pw confirm

  tmp="$(mktemp -p "$parent" ".$name.locked.XXXXXX")"
  trap 'rm -f "$tmp"' EXIT
  start=$(date +%s.%N)   # anything changed in the folder after this is not in the archive
  tar -C "$parent" --zstd -cf - -- "$name" |
    "${GPG[@]}" --symmetric --cipher-algo AES256 --s2k-mode 3 \
      --s2k-digest-algo SHA512 --s2k-count 65011712 --yes -o "$tmp" 3<<<"$pw"

  echo "Checking the locked file against the folder..."
  "${GPG[@]}" --decrypt "$tmp" 3<<<"$pw" | tar -C "$parent" --zstd -df - >/dev/null ||
    die "check failed: the folder was NOT removed (nothing changed)"
  # The check above only compares what's IN the archive: a file saved or moved
  # into the folder while it was being packed would be deleted unseen.
  changed=$(find "$dir" -newerct "@$start" -print -quit)
  [[ -z $changed ]] ||
    die "the folder changed while it was being locked (${changed/#$HOME/\~}); nothing was removed, try again"
  chmod 600 "$tmp"
  mv -- "$tmp" "$out"
  trap - EXIT

  rm -rf -- "$dir"
  echo "Locked: ${out/#$HOME/\~}  (the readable folder was removed)"
  echo "Unlock: unlockdir '${out/#$HOME/\~}'"
  echo "Note: older /home snapshots still hold the readable folder until they expire."
}

unlock() {
  local file parent name dest pw items
  [[ -f $1 ]] || die "no such file: $1"
  file="$(realpath -- "$1")"
  [[ $file == *.locked ]] || die "expected a .locked file: $1"
  parent="$(dirname -- "$file")" name="$(basename -- "$file" .locked)"
  dest="$parent/$name"
  [[ ! -e $dest ]] || die "already exists: $dest (move it away first)"

  ask_password pw
  # Unpack into a hidden temporary folder first: a wrong password or a broken
  # file leaves nothing half-extracted behind.
  tmp="$(mktemp -d -p "$parent" ".$name.unlock.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  "${GPG[@]}" --decrypt "$file" 3<<<"$pw" 2>/dev/null | tar -C "$tmp" --zstd -xf - 2>/dev/null ||
    die "wrong password (or damaged file); nothing changed"
  # The archive holds the folder under its original name; the .locked file may
  # have been renamed since (F2, "Secret (Copy).locked"): take the one folder
  # inside and give it the .locked file's name.
  shopt -s nullglob dotglob; items=("$tmp"/*); shopt -u nullglob dotglob
  [[ ${#items[@]} -eq 1 && -d ${items[0]} ]] || die "wrong password (or damaged file); nothing changed"
  mv -- "${items[0]}" "$dest"
  rm -f -- "$file"
  echo "Unlocked: ${dest/#$HOME/\~}  (the .locked file was removed; lock it again when done)"
}

if [[ ${1:-} == --password-stdin ]]; then PASSWORD_STDIN=1; shift; fi
case "${1:-}" in
  ""|-h|--help) usage ;;
  --unlock)     [[ -n ${2:-} ]] || usage 1; unlock "$2" ;;
  -*)           usage 1 ;;
  *)            lock "$1" ;;
esac

#!/usr/bin/env bash
# Wallpapers (awww). The current one is remembered as the symlink
# ~/Pictures/Wallpapers/current.
#   wallpaper.sh apply <file>   set it with a slanted wipe (matches the reel's
#                               card angle) and remember it
#   wallpaper.sh restore        at login: show the remembered wallpaper
#   wallpaper.sh thumbs         (re)build thumbnails in ~/.cache/wallpaper-thumbs,
#                               only for new/changed files; removes stale ones;
#                               prints "changed=<n>" (the reel reloads images only if n > 0)
set -u
dir="$HOME/Pictures/Wallpapers"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-thumbs"
mkdir -p "$dir" "$cache"

# Wipe angle: the edge leans 18° from vertical like the reel's cards (see
# wallpaper/WallpaperReel.qml), sweeping left to right. Measured, not guessed.
WIPE_ANGLE=162   # awww draws the wipe edge at (angle - 90°): 162 -> edge leaning 18° like "/"

wait_daemon() {
  for _ in $(seq 1 30); do awww query >/dev/null 2>&1 && return 0; sleep 0.1; done
  return 1
}

case "${1:-}" in
  apply)
    file=$(realpath "${2:?file}")
    [[ -f $file ]] || { echo "no such file: $file" >&2; exit 1; }
    fail() { notify-send -a Wallpaper -i dialog-error "Wallpaper not changed" "$1"; exit 1; }
    wait_daemon || fail "The wallpaper daemon (awww-daemon) isn't running."
    awww img "$file" --resize crop \
      --transition-type wipe --transition-angle "$WIPE_ANGLE" \
      --transition-duration 1.1 --transition-fps 60 --transition-bezier .23,1,.32,1 \
      || fail "awww couldn't show ${file##*/}."
    ln -sfn "$file" "$dir/current" ;;

  restore)
    wait_daemon || exit 1
    if [[ -e $dir/current ]]; then
      awww img "$dir/current" --resize crop --transition-type fade --transition-duration 0.6
    else
      awww restore 2>/dev/null || true
    fi ;;

  thumbs)
    shopt -s nullglob nocaseglob
    declare -A keep
    changed=0
    for f in "$dir"/*.{jpg,jpeg,png,webp}; do
      [[ $(basename "$f") == current ]] && continue
      name=$(basename "$f")
      thumb="$cache/$name.jpg"
      keep["$name.jpg"]=1
      # Rebuild when missing or older than the picture. Compare the change time
      # (ctime) too: renaming a file keeps its modified time but updates ctime,
      # so a wallpaper renamed onto an old name (w9 -> w7) gets a new thumbnail.
      if [[ ! -s $thumb || $f -nt $thumb ]] || (( $(stat -c %Z "$f") > $(stat -c %Y "$thumb") )); then
        changed=$((changed + 1))
        magick "$f[0]" -auto-orient -thumbnail '720x405^' -gravity center -extent 720x405 -quality 85 "$thumb" 2>/dev/null &
        # a few in parallel, not hundreds
        (( $(jobs -r | wc -l) >= 4 )) && wait -n
      fi
    done
    wait
    for t in "$cache"/*.jpg; do
      [[ -n ${keep[$(basename "$t")]:-} ]] || { rm -f "$t"; changed=$((changed + 1)); }
    done
    echo "changed=$changed" ;;

  *) echo "usage: $0 apply <file> | restore | thumbs" >&2; exit 2 ;;
esac

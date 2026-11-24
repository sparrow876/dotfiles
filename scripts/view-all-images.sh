#!/usr/bin/env bash
# Open qimgv with every image in a folder AND all its subfolders.
#   view-all-images [folder]        (default: the current folder)
# Also in Nautilus: right-click a folder (or empty space) > "View All Images".
#
# qimgv itself only shows one folder at a time, so this builds a flat folder of
# symlinks in $XDG_RUNTIME_DIR (RAM, gone at logout) and opens that. Each link
# is named after its path, e.g. "Trip › Day 2 › IMG_0042.jpg", so the grid is
# sorted folder by folder. Hidden folders (.git, .cache, ...) are skipped.
# It's for browsing: deleting/renaming in this view only touches the link. Use
# Nautilus to manage the real files (the link name says where each one is).
set -euo pipefail

src=$(realpath -- "${1:-.}")
note() {   # note SUMMARY BODY (the body is shown as markup: escape & < >)
  echo "$*" >&2
  local b=${2//&/&amp;}; b=${b//</&lt;}; b=${b//>/&gt;}
  command -v notify-send >/dev/null && notify-send -a "Image viewer" -i image-x-generic "$1" "$b" || true
}
[[ -d $src ]] || { note "Not a folder" "$src"; exit 1; }

# One stable folder per source folder, so qimgv's thumbnail cache stays valid
base="${XDG_RUNTIME_DIR:-/tmp}/view-all-images"
out="$base/$(printf '%s' "$src" | md5sum | cut -c1-8)/$(basename -- "$src") + subfolders"
rm -rf -- "$out"
mkdir -p -- "$out"

count=0
while IFS= read -r -d '' f; do
  rel=${f#"$src"/}
  name=${rel//\// › }
  ln -s -- "$f" "$out/$name" 2>/dev/null && count=$((count + 1))
# (skips hidden folders and network mounts: Google Drive via rclone would be
# walked and every image downloaded for thumbnails)
done < <(find "$src" -mindepth 1 \( -name '.*' -o -fstype fuse.rclone \) -prune -o -type f -iregex \
  '.*\.\(jpe?g\|jfif\|png\|gif\|webp\|bmp\|tiff?\|svgz?\|avif\|heic\|heif\|jxl\|ico\|tga\|qoi\|psd\|xcf\|exr\|hdr\)' \
  -print0 | sort -zV)

if (( count == 0 )); then
  rmdir -- "$out"
  note "No images" "Nothing found in $(basename -- "$src") or its subfolders."
  exit 0
fi
echo "$count image(s) from $src"
exec qimgv "$out"

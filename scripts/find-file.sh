#!/usr/bin/env bash
# File finder (ALT + SHIFT + F): every file in your home folder, most recently
# changed first, fuzzy search in the shared rofi style.
#   Enter          open it with its default app (zathura, qimgv, mpv, nvim, ...)
#   Shift + Enter  show it in Nautilus (folder opens with the file selected)
# Skips hidden files/folders (fd's default), ~/GoogleDrive (a network mount:
# listing it would download its index) and build/cache folders.
set -u
cd "$HOME" || exit 1

# icon name (Papirus) from the file extension
list() {
  fd --type f --exclude GoogleDrive --exclude node_modules --exclude target \
     --exclude __pycache__ --exclude .git --exec-batch stat -c '%Y %n' 2>/dev/null |
    sort -rn | cut -d' ' -f2- | sed 's|^\./||' |
    awk '{
      ext = tolower($0); sub(/.*\./, "", ext)
      icon = "text-x-generic"
      if (ext ~ /^(pdf)$/) icon = "application-pdf"
      else if (ext ~ /^(png|jpe?g|webp|gif|bmp|svg|avif|heic|jxl|tiff?)$/) icon = "image-x-generic"
      else if (ext ~ /^(mp4|mkv|webm|mov|avi)$/) icon = "video-x-generic"
      else if (ext ~ /^(mp3|flac|ogg|opus|wav|m4a|aac)$/) icon = "audio-x-generic"
      else if (ext ~ /^(zip|7z|tar|gz|xz|zst|rar|bz2)$/) icon = "package-x-generic"
      else if (ext ~ /^(docx?|odt|rtf)$/) icon = "x-office-document"
      else if (ext ~ /^(xlsx?|ods|csv)$/) icon = "x-office-spreadsheet"
      else if (ext ~ /^(pptx?|odp)$/) icon = "x-office-presentation"
      else if (ext ~ /^(tex|bib|cls|sty)$/) icon = "text-x-tex"
      else if (ext ~ /^(md|markdown)$/) icon = "text-markdown"
      else if (ext ~ /^(py)$/) icon = "text-x-python"
      else if (ext ~ /^(rs)$/) icon = "text-rust"
      else if (ext ~ /^(c|h|cpp|hpp|cc)$/) icon = "text-x-csrc"
      else if (ext ~ /^(sh|bash|zsh|lua|qml|js|ts|json|jsonc|toml|ya?ml|conf|ini)$/) icon = "text-x-script"
      printf "%s\0icon\x1f%s\n", $0, icon
    }'
}

choice=$(list | rofi -dmenu -i -p "" -show-icons -no-custom \
    -theme-str 'entry { placeholder: "Find a file in your home folder"; }' \
    -mesg "Enter open · Shift+Enter show in Nautilus" \
    -kb-accept-alt "" -kb-custom-1 "Shift+Return")
code=$?
[[ -z $choice ]] && exit 0
path="$HOME/$choice"
case $code in
  0)  exec xdg-open "$path" ;;
  10) exec nautilus --select "$path" ;;
esac

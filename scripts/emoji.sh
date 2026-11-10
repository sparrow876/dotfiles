#!/usr/bin/env bash
# Emoji picker (ALT + SHIFT + E): rofimoji in the shared rofi style.
# Search by name/keywords; Enter copies the emoji AND types it into the window
# you were in (wtype). Recently used emoji are listed first.
exec rofimoji \
  --selector rofi \
  --action type copy \
  --typer wtype \
  --clipboarder wl-copy \
  --max-recent 10 \
  --skin-tone neutral \
  --prompt "" \
  --selector-args "-theme-str 'entry { placeholder: \"Search emoji\"; }'"

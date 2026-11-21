#!/usr/bin/env bash
# Write ~/.config/qt5ct/qt5ct.conf and ~/.config/qt6ct/qt6ct.conf (Qt apps:
# Fusion style + the Blue Ice colors, Papirus icons, the shell's fonts).
# Not committed: qt*ct needs an absolute path to the color file. The color
# files themselves (qt/.config/qt*ct/colors/rice.conf) are stowed.
# Run by install.sh (step qt). QT_QPA_PLATFORMTHEME=qt6ct (env.lua).
set -euo pipefail
icons=Papirus-Dark

for v in qt5ct qt6ct; do
  dir="$HOME/.config/$v"
  mkdir -p "$dir"
  cat > "$dir/$v.conf" <<CONF
# Written by ~/dotfiles/scripts/qt-config.sh (install.sh step qt). Changes
# here are overwritten on the next run; edit that script instead.
[Appearance]
color_scheme_path=$dir/colors/rice.conf
custom_palette=true
icon_theme=$icons
standard_dialogs=default
style=Fusion

[Fonts]
fixed="JetBrainsMono Nerd Font,11"
general="Noto Sans,11"

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
menus_have_icons=true
show_shortcuts_in_context_menus=true
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3
CONF
done
echo "Qt: qt5ct + qt6ct configured ($icons)"

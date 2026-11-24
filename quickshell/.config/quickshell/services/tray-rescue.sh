#!/usr/bin/env bash
# Bring back tray icons lost when Quickshell restarts.
# Quickshell runs the tray registry (org.kde.StatusNotifierWatcher). When it
# restarts, every tray app should register again; most do (Pomoclock, Claude),
# but ProtonVPN's app doesn't (seen 2026-11-24): its icon stayed gone until the
# app itself restarted. Its tray item is still on D-Bus under its well-known
# name (org.kde.StatusNotifierItem-<id>-<pid>), so this registers every such
# item that isn't registered yet, on the app's behalf. Items already registered
# under their name or their connection id (":1.89/...") are left alone, so
# nothing shows up twice. Run by bar/Tray.qml a few seconds after Quickshell
# starts; prints what it registered.
set -u
W=(org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher)
reg=$(busctl --user get-property "${W[@]}" RegisteredStatusNotifierItems 2>/dev/null) || exit 0

busctl --user list --no-legend 2>/dev/null | awk '$1 ~ /^org\.kde\.StatusNotifierItem-/ { print $1 }' |
while read -r name; do
  owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus \
            GetNameOwner s "$name" 2>/dev/null | awk '{ print $2 }' | tr -d '"')
  [[ $reg == *"\"$name/"* ]] && continue
  [[ -n $owner && $reg == *"\"$owner/"* ]] && continue
  busctl --user call "${W[@]}" RegisterStatusNotifierItem s "$name" >/dev/null 2>&1 &&
    echo "registered $name"
done

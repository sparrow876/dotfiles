// Notifications bell: dot = unread notifications, crossed bell = Do Not Disturb
// (yours, or automatic while a game is fullscreen). Click / ALT + N -> center.
import QtQuick
import qs
import qs.components
import qs.notifications
import qs.services

BarIcon {
    id: bell
    required property var barWindow
    glyph: Notifications.dndActive ? Glyphs.bellOff : Glyphs.bell
    color: Notifications.dndActive ? Theme.muted : Theme.text
    badge: Notifications.unread > 0 && !open
    tooltip: (Notifications.dndActive ? "Do not disturb is on" : "Notifications")
             + (Notifications.unread > 0 ? ` · ${Notifications.unread} new` : "")
    popup: "notifications"
    screenName: barWindow.screen?.name ?? ""

    NotificationCenter { barWindow: bell.barWindow; anchorItem: bell }
}

// Notification server (replaces mako/dunst). Apps send notifications here over
// D-Bus; we keep the history (for the notification center, step 7) and a short
// list of popups shown in the top-right corner.
// - popups auto-hide after 5 s (critical ones stay until dismissed)
// - Do Not Disturb hides popups except critical, history is still kept
// - DND switches on by itself while a game is fullscreen (your own DND setting
//   is untouched, so it's "restored" automatically when the game leaves fullscreen)
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland

Singleton {
    id: root

    property bool dnd: false                      // your switch
    // A Steam game / gamescope window is fullscreen right now
    readonly property bool gameFullscreen: ToplevelManager.toplevels.values.some(
        t => t.fullscreen && /^(steam_app_|gamescope)/.test(t.appId))
    readonly property bool dndActive: dnd || gameFullscreen
    property int unread: 0                        // arrived since the center was last opened
    property var times: ({})                      // notification id -> arrival Date
    readonly property int popupTimeout: 5000
    readonly property int maxPopups: 3

    // Notifications currently shown as popups (newest first)
    property list<QtObject> popups: []
    // Everything still in the history (newest first)
    readonly property var history: server.trackedNotifications.values.slice().reverse()

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true   // keep it for the history
            const t = Object.assign({}, root.times)
            t[notification.id] = new Date()
            root.times = t
            if (!notification.transient) root.unread++
            const critical = notification.urgency === NotificationUrgency.Critical
            if (root.dndActive && !critical) return
            root.popups = [notification].concat(root.popups.filter(n => n !== notification))
            notification.closed.connect(() => root.hidePopup(notification))
        }
    }

    function hidePopup(notification) {
        root.popups = root.popups.filter(n => n !== notification)
    }

    // Popup auto-hide, tracked here (not in the cards) so new popups never reset
    // the timers of older ones. Hovering a card pauses its countdown.
    property var shownFor: ({})      // id -> ms the popup has been visible (unhovered)
    property var hovered: ({})       // id -> true while the mouse is on it
    function setHovered(notification, on) {
        const h = Object.assign({}, root.hovered)
        if (on) h[notification.id] = true
        else delete h[notification.id]
        root.hovered = h
    }
    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            const shown = Object.assign({}, root.shownFor)
            for (const n of root.popups.slice()) {
                if (n.urgency === NotificationUrgency.Critical || root.hovered[n.id]) continue
                shown[n.id] = (shown[n.id] ?? 0) + interval
                if (shown[n.id] >= root.popupTimeout) {
                    delete shown[n.id]
                    root.hidePopup(n)
                }
            }
            root.shownFor = shown
        }
    }
    // Remove from history too (what the ✕ button does)
    function dismiss(notification) {
        hidePopup(notification)
        notification.dismiss()
    }
    // Click on a notification: run its default action, then bring the app's
    // window forward ourselves (apps can't raise themselves: focus stealing is
    // off, misc.focus_on_activate = false). Matches the notification's
    // desktop-entry / app name against open windows' app ids.
    function activate(notification) {
        const def = notification.actions.find(a => a.identifier === "default")
        if (def) def.invoke()
        focusApp(notification)
        hidePopup(notification)
    }
    function focusApp(notification) {
        const keys = [notification.desktopEntry, notification.appName]
            .filter(k => k).map(k => k.toLowerCase().replace(/\.desktop$/, ""))
        if (keys.length === 0) return false
        const wins = ToplevelManager.toplevels.values
        const match = wins.find(t => keys.includes((t.appId || "").toLowerCase()))
                   ?? wins.find(t => keys.some(k => k.length > 2 && (t.appId || "").toLowerCase().includes(k)))
        if (match) { match.activate(); return true }
        return false
    }
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss()
        root.popups = []
        root.unread = 0
    }
    function clearApp(appName) {
        for (const n of server.trackedNotifications.values.slice())
            if ((n.appName || "Other") === appName) dismiss(n)
    }
    function markRead() { root.unread = 0 }

    // Usable source for a notification's app icon: file path, image URL or icon name
    function iconSource(n) {
        const i = n?.appIcon || ""
        if (i.startsWith("/")) return "file://" + i
        if (i.startsWith("file:") || i.startsWith("image:")) return i
        return i ? Quickshell.iconPath(i, true) : ""
    }
    // Picture sent with the notification ("image://icon/<name>" only if it exists)
    function imageSource(n) {
        const img = n?.image || ""
        if (img.startsWith("/")) return "file://" + img
        if (img.startsWith("image://icon/"))
            return Quickshell.iconPath(img.substring(13), true) !== "" ? img : ""
        return img
    }

    // History grouped by app, newest group first: [{ app, icon, items: [...] }]
    readonly property var groups: {
        const out = []
        const index = {}
        for (const n of root.history) {
            const app = n.appName || "Other"
            if (!(app in index)) {
                index[app] = out.length
                out.push({ app: app, icon: n.appIcon, items: [] })
            }
            out[index[app]].items.push(n)
        }
        return out
    }

    function timeAgo(n, now) {
        const t = root.times[n.id]
        if (!t) return ""
        const s = Math.max(0, Math.floor((now - t) / 1000))
        if (s < 60) return "now"
        if (s < 3600) return Math.floor(s / 60) + " min"
        if (s < 86400) return Math.floor(s / 3600) + " h"
        return Qt.formatDate(t, "dd MMM")
    }

    // From a terminal / keybinds:  qs ipc call notifications dnd|clear|status
    IpcHandler {
        target: "notifications"
        function dnd(): void { root.dnd = !root.dnd }
        // testing: act as if the newest notification was clicked
        function clickLatest(): string {
            const n = root.history[0]
            if (!n) return "no notifications"
            const focused = root.focusApp(n)
            return `${n.appName}: ${focused ? "focused its window" : "no matching window"}`
        }
        function status(): string { return `dnd=${root.dnd} game=${root.gameFullscreen} unread=${root.unread} history=${root.history.length}` }
        function clear(): void { root.clearAll() }
    }
}

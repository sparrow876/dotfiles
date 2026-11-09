// Notification server (replaces mako/dunst). Apps send notifications here over
// D-Bus; we keep the history (for the notification center, step 7) and a short
// list of popups shown in the top-right corner.
// - popups auto-hide after 5 s (critical ones stay until dismissed)
// - Do Not Disturb hides popups except critical, history is still kept
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
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
            const critical = notification.urgency === NotificationUrgency.Critical
            if (root.dnd && !critical) return
            if (notification.transient && root.dnd) return
            root.popups = [notification].concat(root.popups.filter(n => n !== notification))
            notification.closed.connect(() => root.hidePopup(notification))
        }
    }

    function hidePopup(notification) {
        root.popups = root.popups.filter(n => n !== notification)
    }
    // Remove from history too (what the ✕ button does)
    function dismiss(notification) {
        hidePopup(notification)
        notification.dismiss()
    }
    // Click on a notification: run its default action (usually "focus the app")
    function activate(notification) {
        const def = notification.actions.find(a => a.identifier === "default")
        if (def) def.invoke()
        hidePopup(notification)
    }
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss()
        root.popups = []
    }

    // From a terminal / keybinds:  qs ipc call notifications dnd
    IpcHandler {
        target: "notifications"
        function dnd(): void { root.dnd = !root.dnd }
        function clear(): void { root.clearAll() }
    }
}

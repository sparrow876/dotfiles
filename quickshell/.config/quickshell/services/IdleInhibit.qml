// Idle inhibitor (coffee cup): while on, the screen never dims, locks or turns
// off. The actual Wayland inhibitor lives in bar/Bar.qml (it needs a window);
// hypridle respects it. Toggle: bar click, ALT + I, or
//   qs ipc call idle toggle
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    // Survives Quickshell reloads (a theme switch reloads the whole shell)
    PersistentProperties {
        id: persist
        reloadableId: "idleInhibit"
        property bool enabled: false
    }
    property alias enabled: persist.enabled

    function toggle() { enabled = !enabled }

    IpcHandler {
        target: "idle"
        function toggle(): void { root.toggle() }
        function status(): string { return root.enabled ? "on" : "off" }
    }
}

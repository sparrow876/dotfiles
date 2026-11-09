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
    property bool enabled: false

    function toggle() { enabled = !enabled }

    IpcHandler {
        target: "idle"
        function toggle(): void { root.toggle() }
        function status(): string { return root.enabled ? "on" : "off" }
    }
}

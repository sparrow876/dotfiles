pragma Singleton
// Full-screen overlays that exist once per monitor: stats panel, power menu,
// wallpaper reel, cheat sheet, idle screen. Their IPC targets live HERE, once.
// (An IpcHandler inside a per-monitor Variants delegate only works for the
// first monitor: Quickshell ignores a second handler for the same target.)
// Each overlay watches its property and opens when it names its monitor.
//   qs ipc call panel|powermenu|wallpaper|cheatsheet toggle
//   qs ipc call idlescreen enter|leave
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // Name of the monitor the overlay is open on; "" = closed
    property string panel: ""
    property string powermenu: ""
    property string wallpaper: ""
    property string cheatsheet: ""
    // The idle screen covers every monitor
    property bool idle: false

    function focusedScreen() { return Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "" }
    function toggle(name) {
        // open on a monitor that has since been unplugged counts as closed
        const open = root[name] !== "" && Quickshell.screens.some(s => s.name === root[name])
        root[name] = open ? "" : focusedScreen()
    }
    // An overlay closed itself (Esc, click outside, action ran)
    function closed(name, screenName) { if (root[name] === screenName) root[name] = "" }

    IpcHandler {
        target: "panel"
        function toggle(): void { root.toggle("panel") }
    }
    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.toggle("powermenu") }
    }
    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.toggle("wallpaper") }
    }
    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { root.toggle("cheatsheet") }
    }
    IpcHandler {
        target: "idlescreen"
        function enter(): void { root.idle = true }
        function leave(): void { root.idle = false }
    }
}

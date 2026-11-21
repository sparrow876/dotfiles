// Window layout mode, shared with Hyprland (scripts/layout-mode.sh):
//   spaced   floating rounded bar + gaps + rounded windows (default)
//   compact  i3-style: no gaps, square windows, the bar a flat strip on the top edge
// The mode is the one word in ~/.local/state/rice/layout; Hyprland reads it on
// config load, this watches it, so the bar follows the bar button, ALT + G and
// a manual `layout-mode.sh compact` alike.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string mode: "spaced"
    readonly property bool compact: mode === "compact"

    function toggle() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/dotfiles/scripts/layout-mode.sh", "toggle"])
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice/layout"
        watchChanges: true
        printErrors: false            // no file yet = spaced
        onFileChanged: reload()
        onLoaded: root.mode = text().trim() === "compact" ? "compact" : "spaced"
        onLoadFailed: root.mode = "spaced"
    }
}

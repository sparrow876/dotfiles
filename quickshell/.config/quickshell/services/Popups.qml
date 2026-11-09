// Which bar popup is open (only one at a time, on one screen).
// Popups.toggle("network", screenName[, clicked]) / Popups.close()
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property string current: ""
    property string screen: ""
    // true when opened by clicking the bar (a normal grabbing popup works);
    // false when opened by a keybind / IPC: Wayland refuses a grabbing popup
    // unless the bar itself just got input, so those use Hyprland's focus grab.
    property bool byClick: true

    function toggle(name, screenName, clicked) {
        if (current === name && screen === screenName) close()
        else { byClick = clicked ?? true; current = name; screen = screenName }
    }
    function close() { current = ""; screen = "" }
    function isOpen(name, screenName) { return current === name && screen === screenName }
}

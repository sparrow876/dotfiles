// Which bar popup is open (only one at a time, on one screen).
// Popups.toggle("network", screenName) / Popups.close()
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    property string current: ""
    property string screen: ""

    function toggle(name, screenName) {
        if (current === name && screen === screenName) close()
        else { current = name; screen = screenName }
    }
    function close() { current = ""; screen = "" }
    function isOpen(name, screenName) { return current === name && screen === screenName }
}

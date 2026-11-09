// Screen brightness (0..1) from /sys/class/backlight. Reacts to *any* change
// (keys, hypridle dimming, other tools): a single `udevadm monitor` process
// reports kernel "change" events for the backlight; we then re-read the value.
// No polling. No keyboard backlight is exposed on this laptop.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int current: 0
    readonly property real value: max > 0 ? current / max : 0
    readonly property bool available: device !== "" && max > 0

    // Find the backlight device once (intel_backlight on this laptop)
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector { onStreamFinished: root.device = text.trim() }
    }

    FileView {
        id: maxFile
        path: root.device ? `/sys/class/backlight/${root.device}/max_brightness` : ""
        onLoaded: root.max = parseInt(text()) || 0
    }
    FileView {
        id: curFile
        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        onLoaded: root.current = parseInt(text()) || 0
    }

    // A reload (theme switch) doesn't stop old child processes: stop it here
    Component.onDestruction: udev.running = false
    Process {
        id: udev
        running: root.device !== ""
        // setpriv --pdeathsig: udevadm exits if Quickshell is killed or crashes
        command: ["setpriv", "--pdeathsig", "TERM", "udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: line => { if (line.includes(" change ")) curFile.reload() }
        }
    }
}

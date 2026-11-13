// Screen brightness (0..1) from /sys/class/backlight. Reacts to *any* change
// (keys, hypridle dimming, other tools): a single `udevadm monitor` process
// reports kernel "change" events for the backlight; we then re-read the value.
// No polling. No keyboard backlight is exposed on this laptop.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

Singleton {
    id: root

    property string device: ""
    property int max: 0
    property int current: 0
    readonly property real value: max > 0 ? current / max : 0
    readonly property bool available: device !== "" && max > 0
    readonly property int percent: Math.round(value * 100)
    readonly property string glyph: Glyphs.brightnessLevels[value < 0.34 ? 0 : value < 0.67 ? 1 : 2]

    // Set brightness (0..1). Never fully black: at least 1%. Calls while a
    // slider is dragged are merged, so brightnessctl runs at most every 40 ms.
    property real pending: -1
    function set(v) {
        pending = Math.max(0.01, Math.min(1, v))
        if (!setTimer.running) setTimer.start()
    }
    function step(n) { set(Math.round(value * 20 + n) / 20) }   // n x 5%, snapped to 5% steps
    Timer {
        id: setTimer
        interval: 40
        onTriggered: {
            if (root.pending < 0) return
            Quickshell.execDetached(["brightnessctl", "-q", "-n2", "set", Math.round(root.pending * 100) + "%"])
            root.pending = -1
        }
    }

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

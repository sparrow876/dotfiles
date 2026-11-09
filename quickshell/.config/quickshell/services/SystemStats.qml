// System stats for the stats panel. Polls ONLY while the panel is open
// (active = true): every 1.5 s it runs services/sysstats.sh (one JSON snapshot)
// and turns counters into rates. Keeps ~60 s of history for the graphs.
// Nothing runs while the panel is closed.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    readonly property int interval: 1500
    readonly property int historyLength: 40          // 40 x 1.5 s = 60 s

    // Latest values (null / empty until the first two snapshots arrive)
    property var snap: null
    property real cpu: 0                              // 0..1
    property var cores: []                            // 0..1 each
    property var cpuHistory: []
    property real mem: 0
    property real swap: 0
    property var memHistory: []
    property real rxRate: 0                           // bytes/s
    property real txRate: 0
    property var rxHistory: []
    property var txHistory: []
    property real readRate: 0                         // bytes/s
    property real writeRate: 0

    property var prev: null                           // previous snapshot, for rates
    property real prevTime: 0

    function push(list, v) {
        const out = list.concat([v])
        return out.length > historyLength ? out.slice(out.length - historyLength) : out
    }

    onActiveChanged: {
        if (active) poll()
        else { prev = null; cpuHistory = []; memHistory = []; rxHistory = []; txHistory = [] }
    }
    Timer {
        running: root.active
        interval: root.interval
        repeat: true
        onTriggered: root.poll()
    }
    function poll() { if (!proc.running) proc.running = true }

    Process {
        id: proc
        command: [Quickshell.shellPath("services/sysstats.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active) return       // finished after the panel closed
                let s
                try { s = JSON.parse(text) } catch (e) { console.warn("sysstats.sh: bad JSON:", e); return }
                root.update(s)
            }
        }
    }

    function update(s) {
        const now = Date.now()
        const p = root.prev
        const dt = p ? (now - root.prevTime) / 1000 : 0
        snap = s

        if (p && dt > 0) {
            // CPU from jiffy deltas: [busy, total] for "cpu" then each core
            const usage = (a, b) => (b[1] - a[1]) > 0 ? Math.max(0, Math.min(1, (b[0] - a[0]) / (b[1] - a[1]))) : 0
            cpu = usage(p.cpu[0], s.cpu[0])
            cores = s.cpu.slice(1).map((c, i) => usage(p.cpu[i + 1] ?? c, c))
            cpuHistory = push(cpuHistory, cpu)

            if (s.net && p.net && s.net.iface === p.net.iface) {
                rxRate = Math.max(0, (s.net.rx - p.net.rx) / dt)
                txRate = Math.max(0, (s.net.tx - p.net.tx) / dt)
                rxHistory = push(rxHistory, rxRate)
                txHistory = push(txHistory, txRate)
            }
            if (s.diskio && p.diskio) {
                readRate = Math.max(0, (s.diskio[0] - p.diskio[0]) * 512 / dt)
                writeRate = Math.max(0, (s.diskio[1] - p.diskio[1]) * 512 / dt)
            }
        }
        mem = s.mem.total > 0 ? 1 - s.mem.avail / s.mem.total : 0
        swap = s.mem.swapTotal > 0 ? 1 - s.mem.swapFree / s.mem.swapTotal : 0
        memHistory = push(memHistory, mem)

        prev = s
        prevTime = now
    }

    // --- Formatting helpers ---------------------------------------------------
    function bytes(n) {
        const u = ["B", "KiB", "MiB", "GiB", "TiB"]
        let i = 0
        while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
        return (i === 0 ? Math.round(n) : n.toFixed(n < 10 ? 1 : 0)) + " " + u[i]
    }
    function rate(n) { return bytes(n) + "/s" }
    function duration(seconds) {
        const d = Math.floor(seconds / 86400), h = Math.floor(seconds % 86400 / 3600), m = Math.floor(seconds % 3600 / 60)
        return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`
    }
    // Warning colors: returns "normal" | "warn" | "critical"
    function level(value, warnAt, critAt) { return value >= critAt ? "critical" : value >= warnAt ? "warn" : "normal" }
}

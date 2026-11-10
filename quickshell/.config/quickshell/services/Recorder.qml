// Screen recording with gpu-screen-recorder. It captures and encodes on the GPU
// that drives the screen, i.e. the Intel iGPU's hardware encoder (Quick Sync):
// near-zero CPU, and the RTX 3050 can stay asleep. NVENC would only be used if
// the NVIDIA card drove the display (not the setup chosen here).
//   ALT + R          start/stop recording the focused monitor
//   ALT + SHIFT + R  start/stop recording a selected region
//   ALT + CTRL + R   replay mode off -> turn it on; on -> save the last 60 s
//   ALT + CTRL + SHIFT + R  turn replay mode on / off
// Desktop audio always; microphone optional (bar indicator right-click menu).
// Files: ~/Videos/Recordings. On save: notification with Open + Open folder.
//   qs ipc call recorder toggleFull|toggleRegion|replay|toggleReplay|toggleMic|status
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Videos/Recordings"
    readonly property string notifyScript: Quickshell.env("HOME") + "/dotfiles/scripts/notify-file.sh"

    property bool recording: false
    property bool region: false
    property bool mic: false
    property bool replay: false                  // replay buffer running
    property string file: ""
    property string lastError: ""                 // last "error" line from gpu-screen-recorder
    property real startedAt: 0
    property int elapsed: 0                       // seconds

    readonly property string audio: mic ? "default_output|default_input" : "default_output"
    function monitor() { return Hyprland.focusedMonitor?.name ?? "screen" }
    function hex(c) { return c.toString().substring(1, 7) }   // "#rrggbb" -> "rrggbb"
    function stamp() { return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") }   // local time

    // --- normal recording ------------------------------------------------------
    function toggleFull() { recording ? stop() : start(["-w", monitor()]) }
    function toggleRegion() {
        if (recording) { stop(); return }
        selector.running = true
    }
    function start(captureArgs) {
        region = captureArgs.includes("region")
        file = `${dir}/${stamp()}.mp4`
        // setpriv --pdeathsig INT: if Quickshell dies, the recorder finishes the
        // file and exits instead of recording forever in the background
        rec.command = ["setpriv", "--pdeathsig", "INT", "gpu-screen-recorder"].concat(captureArgs, [
            "-f", "60", "-a", audio, "-c", "mp4", "-q", "very_high", "-o", file])
        rec.running = true
    }
    function stop() { if (rec.running) rec.signal(2) }   // SIGINT: finish the file cleanly

    Process {
        id: selector
        command: ["slurp", "-f", "%wx%h+%x+%y", "-d",
                  "-b", root.hex(Theme.base) + "66", "-c", root.hex(Theme.lightBlue) + "ff",
                  "-s", root.hex(Theme.lightBlue) + "22", "-w", "2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const g = text.trim()
                if (/^\d+x\d+\+-?\d+\+-?\d+$/.test(g)) root.start(["-w", "region", "-region", g])
            }
        }
    }

    Process {
        id: rec
        onStarted: {
            root.lastError = ""
            root.recording = true
            root.startedAt = Date.now()
            root.elapsed = 0
        }
        // "Saved" only when gpu-screen-recorder finished cleanly (exit 0) AND the
        // file exists; otherwise say it failed, with its error message
        onExited: (code, status) => {
            root.recording = false
            Quickshell.execDetached(["bash", "-c",
                '[[ $1 == 0 && -s $2 ]] && exec "$3" "Screen recording" "Recording saved" "${2##*/}" "$2" video-x-generic open folder; ' +
                'notify-send -u critical -a "Screen recording" -i dialog-error "Recording failed" "$4"',
                "recorder", String(code), root.file, root.notifyScript,
                root.lastError || `gpu-screen-recorder stopped with code ${code}`])
        }
        stderr: SplitParser {
            onRead: line => {
                if (/error/i.test(line)) { console.warn("gpu-screen-recorder:", line); root.lastError = line }
            }
        }
    }
    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
    }

    // --- replay buffer (last 60 s kept in RAM) ----------------------------------
    function toggleReplay() {
        if (replayProc.running) {
            root.stoppingReplay = true
            replayProc.signal(2)
            Quickshell.execDetached(["notify-send", "-a", "Screen recording", "-i", "media-record", "Replay mode off"])
            return
        }
        root.replayError = ""
        replayProc.command = ["setpriv", "--pdeathsig", "INT", "gpu-screen-recorder", "-w", monitor(), "-f", "60", "-a", audio,
                              "-c", "mp4", "-q", "very_high", "-r", "60", "-replay-storage", "ram", "-o", dir]
        replayProc.running = true
    }
    // ALT + CTRL + R: save if running, otherwise start replay mode
    function replayKey() {
        if (!replayProc.running) {
            toggleReplay()        // "Replay mode on" is announced once it really started
        } else {
            replayProc.signal(10)   // SIGUSR1: save the buffer
        }
    }
    property bool stoppingReplay: false
    property string replayError: ""
    Process {
        id: replayProc
        onRunningChanged: root.replay = running
        onStarted: Quickshell.execDetached(["notify-send", "-a", "Screen recording", "-i", "media-record",
            "Replay mode on", "The last 60 s are kept in memory. ALT + CTRL + R saves them."])
        // Stopped by itself (not by us): say why
        onExited: (code, status) => {
            if (!root.stoppingReplay)
                Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Screen recording", "-i", "dialog-error",
                    "Replay mode failed", root.replayError || `gpu-screen-recorder stopped with code ${code}`])
            root.stoppingReplay = false
        }
        stderr: SplitParser {
            onRead: line => { if (/error/i.test(line)) root.replayError = line }
        }
        // gpu-screen-recorder prints the saved file's path on stdout
        stdout: SplitParser {
            onRead: line => {
                const path = line.trim()
                if (path.endsWith(".mp4"))
                    Quickshell.execDetached([root.notifyScript, "Screen recording", "Replay saved",
                        path.split("/").pop(), path, "video-x-generic", "open", "folder"])
            }
        }
    }

    function toggleMic() { mic = !mic }

    // A Quickshell reload (theme switch, config edit) doesn't stop child
    // processes: finish a recording cleanly and end replay mode instead of
    // leaving an invisible recorder running. (theme/apply.sh also refuses to
    // switch themes while recording.)
    Component.onDestruction: {
        if (rec.running) rec.signal(2)
        if (replayProc.running) { root.stoppingReplay = true; replayProc.signal(2) }
    }

    IpcHandler {
        target: "recorder"
        function toggleFull(): void { root.toggleFull() }
        function toggleRegion(): void { root.toggleRegion() }
        function replay(): void { root.replayKey() }
        function toggleReplay(): void { root.toggleReplay() }
        function toggleMic(): void { root.toggleMic() }
        function status(): string { return `recording=${root.recording} elapsed=${root.elapsed} replay=${root.replay} mic=${root.mic} file=${root.file}` }
    }
}

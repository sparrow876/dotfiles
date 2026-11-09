// Audio state from PipeWire (Quickshell.Services.Pipewire, event-driven).
// Used by bar/AudioIcon.qml, popups/AudioMenu.qml and (later) the OSD.
// Volume is capped at 100%. "Pro Audio" devices are hidden: that profile has no
// speaker routing (it silenced the speakers once, see MAINTENANCE.md).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.components

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function isPro(node) {
        return node.properties["device.profile.pro"] === "true" || node.name.includes("pro-output") || node.name.includes("pro-input")
    }
    readonly property var nodes: Pipewire.nodes.values
    // Filter on node type flags: properties (names, media.class) are only
    // filled in once a node is tracked, the type is always known.
    readonly property var sinks: nodes.filter(n => n.type === PwNodeType.AudioSink && !isPro(n))
    readonly property var sources: nodes.filter(n => n.type === PwNodeType.AudioSource && !isPro(n))
    readonly property var streams: nodes.filter(n => n.type === PwNodeType.AudioOutStream)

    // Track every audio device + app stream so their names and volumes are live
    PwObjectTracker { objects: root.sinks.concat(root.sources, root.streams) }

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property string glyph: muted || volume <= 0.001 ? Glyphs.volumeMuted
                                  : volume < 0.34 ? Glyphs.volumeLow
                                  : volume < 0.67 ? Glyphs.volumeMid
                                  : Glyphs.volumeHigh

    // Short device label: "Speaker", "HDMI 1", "Digital Microphone", headset name...
    function nodeName(node) {
        if (!node) return "Unknown"
        return node.properties["node.nick"] || node.nickname || node.description || node.name
    }
    function nodeGlyph(node) {
        const p = node?.properties ?? {}
        const name = (p["node.nick"] || "") + " " + (node?.name ?? "")
        if (p["device.api"] === "bluez5") return Glyphs.headphones
        if (/hdmi|displayport/i.test(name)) return Glyphs.monitor
        if (/headphone|headset/i.test(name)) return Glyphs.headphones
        if (!node?.isSink) return Glyphs.mic
        return Glyphs.speaker
    }
    function appName(stream) {
        const p = stream.properties
        return p["application.name"] || p["media.name"] || stream.name
    }
    // App icon: the stream's icon name, else its program or app name, else generic
    function appIcon(stream) {
        const p = stream.properties
        const candidates = [p["application.icon-name"], p["application.process.binary"],
                            (p["application.name"] || "").toLowerCase()]
        for (const name of candidates) {
            if (!name) continue
            const path = Quickshell.iconPath(name.replace(/-bin$/, ""), true)
            if (path) return path
        }
        return Quickshell.iconPath("application-x-executable")
    }

    function setVolume(node, value) { if (node?.audio) { node.audio.muted = false; node.audio.volume = Math.max(0, Math.min(1, value)) } }
    function toggleMute(node) { if (node?.audio) node.audio.muted = !node.audio.muted }
    function setDefaultSink(node) { Pipewire.preferredDefaultAudioSink = node }
    function setDefaultSource(node) { Pipewire.preferredDefaultAudioSource = node }

    // Debugging from a terminal:  qs ipc call audio devices
    IpcHandler {
        target: "audio"
        function devices(): string {
            return root.nodes.map(n => `${n.isSink ? "sink  " : "source"} stream=${n.isStream} type=${n.type} audio=${!!n.audio} class=${n.properties["media.class"]} nick=${n.properties["node.nick"]} name=${n.name}`).join("\n")
        }
    }
}

// The media player shown in the bar (MPRIS: Zen/Firefox, mpv, Spotify, ...).
// Picks the player that's playing; if none is, the one that played last.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var lastActive: null

    readonly property var player: {
        const playing = players.find(p => p.isPlaying)
        if (playing) return playing
        if (lastActive && players.includes(lastActive)) return lastActive
        return players.find(p => p.trackTitle) ?? null
    }
    onPlayerChanged: if (player?.isPlaying) lastActive = player
    Connections {
        target: root.player
        function onIsPlayingChanged() {
            if (!root.player.isPlaying) return
            // During a skip burst that began paused, any "playing" report is
            // the player auto-starting a skipped-to track: pause it again
            // (every time, not just once: each skip can restart it)
            if (root.burstActive && root.burstWasPaused) {
                if (root.player.canPause) root.player.pause()
                return
            }
            root.lastActive = root.player
        }
    }

    // Skipping keeps the play/pause state. MPRIS has no "skip but stay
    // paused" and players start the new track on Next/Previous, so:
    // - a burst of skips (clicking next/previous quickly) counts as one: the state
    //   is taken at the FIRST skip and kept until 2.5 s after the last one
    //   (re-reading it mid-burst saw the auto-started track as "playing")
    // - pause is sent right after each skip (MPD runs commands in order, so
    //   usually no sound at all) and again whenever the player reports playing
    property bool burstActive: false
    property bool burstWasPaused: false
    Timer { id: burstTimer; interval: 2500; onTriggered: root.burstActive = false }
    function skip(action) {
        if (!root.burstActive) {
            root.burstWasPaused = !root.isPlaying
            root.burstActive = true
        }
        burstTimer.restart()
        const p = root.player
        action()
        if (root.burstWasPaused && p?.canPause) p.pause()
    }

    readonly property bool isPlaying: player?.isPlaying ?? false
    readonly property bool hasTrack: (player?.trackTitle ?? "") !== ""
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string label: artist && title ? `${artist} — ${title}` : (title || artist)

    function toggle() { if (player?.canTogglePlaying) player.togglePlaying() }
    function next() { if (player?.canGoNext) skip(() => player.next()) }
    function previous() { if (player?.canGoPrevious) skip(() => player.previous()) }
}

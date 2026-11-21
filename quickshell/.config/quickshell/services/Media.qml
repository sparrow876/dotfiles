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
            // skipped while paused: the player started the new track by
            // itself (MPRIS has no "skip but stay paused"), so pause it again
            if (root.keepPaused) {
                root.keepPaused = false
                if (root.player.canPause) root.player.pause()
                return
            }
            root.lastActive = root.player
        }
    }

    // Skipping keeps the play/pause state: armed for 2 s after a skip made
    // while paused (long enough for the player to report the new state)
    property bool keepPaused: false
    Timer { id: keepPausedTimer; interval: 2000; onTriggered: root.keepPaused = false }
    function skip(action) {
        const wasPaused = !root.isPlaying
        action()
        if (wasPaused) { root.keepPaused = true; keepPausedTimer.restart() }
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

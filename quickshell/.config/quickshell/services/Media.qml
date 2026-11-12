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
        function onIsPlayingChanged() { if (root.player.isPlaying) root.lastActive = root.player }
    }

    readonly property bool isPlaying: player?.isPlaying ?? false
    readonly property bool hasTrack: (player?.trackTitle ?? "") !== ""
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string label: artist && title ? `${artist} — ${title}` : (title || artist)

    function toggle() { if (player?.canTogglePlaying) player.togglePlaying() }
    function next() { if (player?.canGoNext) player.next() }
    function previous() { if (player?.canGoPrevious) player.previous() }
}

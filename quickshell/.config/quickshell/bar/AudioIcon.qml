// Output volume: glyph (low / mid / high / muted) + a small level bar.
// Click -> AudioMenu,
// scroll -> ±5% (max 100%), middle-click -> mute.
import QtQuick
import qs
import qs.components
import qs.popups
import qs.services

BarIcon {
    id: icon
    required property var barWindow
    glyph: Audio.glyph
    color: Audio.muted ? Theme.muted : Theme.text
    tooltip: Audio.muted ? "Muted" : `Volume ${Math.round(Audio.volume * 100)}%`
    popup: "audio"
    screenName: barWindow.screen?.name ?? ""

    // Left click is handled by BarIcon (opens the menu); middle click mutes
    onClicked: event => { if (event.button === Qt.MiddleButton) Audio.toggleMute(Audio.sink) }
    // Scroll: ±5% per wheel notch (touchpad scrolling accumulates)
    WheelSteps { id: wheel }
    onWheel: event => { const n = wheel.steps(event); if (n) Audio.setVolume(Audio.sink, Audio.volume + 0.05 * n) }

    LevelBar {
        value: Audio.volume
        dimmed: Audio.muted
    }

    AudioMenu { barWindow: icon.barWindow; anchorItem: icon }
}

// Output volume (low / mid / high / muted). Click -> AudioMenu,
// scroll -> ±5% (max 100%), middle-click -> mute.
import QtQuick
import qs
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
    onWheel: event => Audio.setVolume(Audio.sink, Audio.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))

    AudioMenu { barWindow: icon.barWindow; anchorItem: icon }
}

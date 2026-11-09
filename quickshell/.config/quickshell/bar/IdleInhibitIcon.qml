// Idle inhibitor: coffee cup. Outline = off (normal idle: dim, lock, screen off),
// filled light blue = on (stay awake). Click or ALT + I toggles.
import QtQuick
import qs
import qs.components
import qs.services

BarIcon {
    glyph: IdleInhibit.enabled ? Glyphs.coffee : Glyphs.coffeeOutline
    color: IdleInhibit.enabled ? Theme.lightBlue : Theme.text
    tooltip: IdleInhibit.enabled
             ? "Staying awake: screen won't dim, lock or turn off. Click to allow idle again."
             : "Idle inhibitor off. Click (or ALT + I) to keep the screen awake."
    onClicked: event => { if (event.button === Qt.LeftButton) IdleInhibit.toggle() }
}

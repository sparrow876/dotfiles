// Screen brightness: sun glyph (fuller with the level) + a small level bar.
// Click -> BrightnessMenu (slider + presets), scroll -> ±5%,
// middle-click -> toggle between the current level and full brightness.
import QtQuick
import qs
import qs.components
import qs.popups
import qs.services

BarIcon {
    id: icon
    required property var barWindow
    visible: Brightness.available
    glyph: Brightness.glyph
    tooltip: `Brightness ${Brightness.percent}%`
    popup: "brightness"
    screenName: barWindow.screen?.name ?? ""

    property real beforeFull: -1
    onClicked: event => {
        if (event.button !== Qt.MiddleButton) return
        if (Brightness.value < 0.99) { beforeFull = Brightness.value; Brightness.set(1) }
        else if (beforeFull > 0) { Brightness.set(beforeFull); beforeFull = -1 }
    }
    WheelSteps { id: wheel }
    onWheel: event => { const n = wheel.steps(event); if (n) Brightness.step(n) }

    LevelBar { value: Brightness.value }

    BrightnessMenu { barWindow: icon.barWindow; anchorItem: icon }
}

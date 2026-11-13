// Brightness popup (bar sun icon): big percentage, a slider between a dim and a
// bright sun (each also a 5% step button), and quick presets.
// Scroll anywhere on the slider: ±5%. The OSD stays quiet while this is open.
import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

PopupFrame {
    id: menu
    name: "brightness"
    contentWidth: 330

    // Header: glyph, title, percentage
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Icon {
            text: Brightness.glyph
            size: 20
            color: Theme.lightBlue
        }
        StyledText {
            text: "Screen brightness"
            font.weight: Font.Bold
            Layout.fillWidth: true
        }
        StyledText {
            text: Brightness.percent + "%"
            font.pixelSize: Theme.fontSize + 5
            font.weight: Font.Bold
            color: Theme.ice
        }
    }

    // Slider with step buttons on both ends
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        IconButton {
            glyph: Glyphs.brightnessLevels[0]
            size: 16
            color: Theme.muted
            tooltip: "Dimmer (5%)"
            onClicked: Brightness.step(-1)
        }
        Slider {
            Layout.fillWidth: true
            value: Brightness.pending >= 0 ? Brightness.pending : Brightness.value
            onMoved: v => Brightness.set(v)
        }
        IconButton {
            glyph: Glyphs.brightnessLevels[2]
            size: 18
            color: Theme.ice
            tooltip: "Brighter (5%)"
            onClicked: Brightness.step(1)
        }
    }

    // Presets: the one closest to the current level is highlighted
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [10, 25, 50, 75, 100]
            delegate: TextButton {
                required property int modelData
                Layout.fillWidth: true
                label: modelData + "%"
                primary: Math.abs(Brightness.percent - modelData) <= 2
                onClicked: Brightness.set(modelData / 100)
            }
        }
    }

    StyledText {
        text: "Scroll on the sun in the bar: ±5% · middle-click: full brightness and back"
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall - 1
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}

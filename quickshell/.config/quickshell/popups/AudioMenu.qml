// Audio menu: output volume + mute + device list (speakers, HDMI, Bluetooth),
// input volume + mute + device list, and a slider per app that's playing sound.
// "Advanced…" opens pavucontrol. Volume is capped at 100%.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PopupFrame {
    id: menu
    name: "audio"
    contentWidth: 380

    // --- Output ---------------------------------------------------------------
    SectionHeader { title: "Output" }
    VolumeRow {
        node: Audio.sink
        glyph: Audio.glyph
        Layout.fillWidth: true
    }
    Repeater {
        model: ScriptModel { values: Audio.sinks.length > 1 ? Audio.sinks : [] }
        delegate: DeviceChoice {
            required property var modelData
            Layout.fillWidth: true
            label: Audio.nodeName(modelData)
            glyph: Audio.nodeGlyph(modelData)
            selected: Audio.sink === modelData
            onClicked: Audio.setDefaultSink(modelData)
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.overlay }

    // --- Input ----------------------------------------------------------------
    SectionHeader { title: "Input" }
    VolumeRow {
        node: Audio.source
        glyph: Audio.micMuted ? Glyphs.micOff : Glyphs.mic
        Layout.fillWidth: true
    }
    Repeater {
        model: ScriptModel { values: Audio.sources.length > 1 ? Audio.sources : [] }
        delegate: DeviceChoice {
            required property var modelData
            Layout.fillWidth: true
            label: Audio.nodeName(modelData)
            glyph: Audio.nodeGlyph(modelData)
            selected: Audio.source === modelData
            onClicked: Audio.setDefaultSource(modelData)
        }
    }

    // --- Apps -----------------------------------------------------------------
    Rectangle { visible: Audio.streams.length > 0; Layout.fillWidth: true; implicitHeight: 1; color: Theme.overlay }
    SectionHeader { visible: Audio.streams.length > 0; title: "Apps" }
    // Scrolls when many apps play at once, so the menu never outgrows the screen
    Flickable {
        id: appsFlick
        visible: Audio.streams.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(appsCol.implicitHeight, 260)
        contentHeight: appsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ColumnLayout {
            id: appsCol
            width: appsFlick.width
            spacing: 10
            Repeater {
                model: ScriptModel { values: Audio.streams }
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10
                    IconImage {
                        source: Audio.appIcon(modelData)
                        implicitSize: 22
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        StyledText {
                            text: Audio.appName(modelData)
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Slider {
                            Layout.fillWidth: true
                            value: modelData.audio?.volume ?? 0
                            muted: modelData.audio?.muted ?? false
                            onMoved: v => Audio.setVolume(modelData, v)
                        }
                    }
                    StyledText {
                        text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeSmall
                        Layout.preferredWidth: 38
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }

    // --- Footer ---------------------------------------------------------------
    TextButton {
        label: "Advanced…"
        Layout.alignment: Qt.AlignRight
        onClicked: {
            Quickshell.execDetached(["pavucontrol"])
            Popups.close()
        }
    }

    component SectionHeader: StyledText {
        property string title
        text: title
        font.weight: Font.Bold
    }

    // Mute button + slider + percentage for one device
    component VolumeRow: RowLayout {
        id: vr
        property var node
        property string glyph
        spacing: 8
        IconButton {
            glyph: vr.glyph
            size: 18
            color: vr.node?.audio?.muted ? Theme.muted : Theme.lightBlue
            tooltip: vr.node?.audio?.muted ? "Unmute" : "Mute"
            onClicked: Audio.toggleMute(vr.node)
        }
        Slider {
            Layout.fillWidth: true
            value: vr.node?.audio?.volume ?? 0
            muted: vr.node?.audio?.muted ?? false
            onMoved: v => Audio.setVolume(vr.node, v)
        }
        StyledText {
            text: Math.round((vr.node?.audio?.volume ?? 0) * 100) + "%"
            color: Theme.muted
            Layout.preferredWidth: 42
            horizontalAlignment: Text.AlignRight
        }
    }

    // One selectable device in a list
    component DeviceChoice: MouseArea {
        id: dc
        property string label
        property string glyph
        property bool selected
        implicitHeight: 32
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: dc.containsMouse ? Theme.overlay : "transparent"
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            spacing: 10
            Icon {
                text: dc.selected ? "󰐾" : "󰄰"   // nf-md-radiobox_marked / blank
                color: dc.selected ? Theme.lightBlue : Theme.muted
                size: 15
            }
            Icon {
                text: dc.glyph
                color: dc.selected ? Theme.text : Theme.muted
                size: 16
            }
            StyledText {
                text: dc.label
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall + 1
                color: dc.selected ? Theme.text : Theme.muted
                Layout.fillWidth: true
            }
        }
    }
}

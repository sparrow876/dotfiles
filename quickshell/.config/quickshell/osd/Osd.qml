// On-screen indicator: a frosted pill at the bottom-center (~280px) with icon,
// level bar and percentage. Shows for volume, mute, mic mute, screen brightness
// and idle-inhibitor changes, whatever caused them (keys, bar, other apps).
// Hides after 1.5 s. Never takes focus; clicks pass through it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: osd
    required property ShellScreen modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors.bottom: true
    margins.bottom: 56
    implicitWidth: 280
    implicitHeight: 52
    color: "transparent"
    mask: Region {}          // fully click-through
    visible: false

    property string glyph: ""
    property string label: ""
    property real level: -1  // -1 = no bar, just the label
    property bool dimmed: false

    // Ignore the burst of "changes" while services load at startup
    property bool ready: false
    Timer { running: true; interval: 2000; onTriggered: osd.ready = true }

    function show(g, value, lbl, isDimmed) {
        if (!ready) return
        if (osd.modelData.name !== Overlays.focusedScreen()) return   // one pill, on the focused monitor
        glyph = g
        level = value
        label = lbl
        dimmed = isDimmed
        if (!visible || hideAnim.running) {
            hideAnim.stop()
            visible = true
            showAnim.restart()
        }
        hideTimer.restart()
    }

    Connections {
        target: Audio
        function onVolumeChanged() { osd.show(Audio.glyph, Audio.volume, "", Audio.muted) }
        function onMutedChanged() { osd.show(Audio.glyph, Audio.volume, "", Audio.muted) }
        function onMicMutedChanged() {
            osd.show(Audio.micMuted ? Glyphs.micOff : Glyphs.mic, -1,
                     Audio.micMuted ? "Microphone muted" : "Microphone on", Audio.micMuted)
        }
    }
    Connections {
        target: Brightness
        function onCurrentChanged() {
            const v = Brightness.value
            osd.show(Glyphs.brightnessLevels[v < 0.34 ? 0 : v < 0.67 ? 1 : 2], v, "", false)
        }
    }
    Connections {
        target: IdleInhibit
        function onEnabledChanged() {
            osd.show(IdleInhibit.enabled ? Glyphs.coffee : Glyphs.coffeeOutline, -1,
                     IdleInhibit.enabled ? "Staying awake" : "Idle allowed again", !IdleInhibit.enabled)
        }
    }

    Timer { id: hideTimer; interval: 1500; onTriggered: hideAnim.restart() }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Theme.glass
        border.width: 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)
        opacity: 0
        transform: Translate { id: slide; y: 12 }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 14

            Icon {
                text: osd.glyph
                size: 22
                color: osd.dimmed ? Theme.muted : Theme.lightBlue
            }
            LevelBar {
                visible: osd.level >= 0
                Layout.fillWidth: true
                implicitHeight: 7
                value: Math.max(0, osd.level)
                dimmed: osd.dimmed
            }
            StyledText {
                visible: osd.level >= 0
                text: Math.round(Math.max(0, osd.level) * 100) + "%"
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
            }
            StyledText {
                visible: osd.level < 0
                text: osd.label
                Layout.fillWidth: true
            }
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: pill; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutQuint }
        NumberAnimation { target: slide; property: "y"; to: 0; duration: 220; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: pill; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InOutCubic }
            NumberAnimation { target: slide; property: "y"; to: 12; duration: 180; easing.type: Easing.InOutCubic }
        }
        ScriptAction { script: osd.visible = false }
    }
}

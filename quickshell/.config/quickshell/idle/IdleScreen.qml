// Idle screen (shown by hypridle after 4 min idle, with the screen dimmed):
// full-screen palette background with a slowly drifting gradient, a large clock
// and date, and what's playing. Fades in over ~1 s. Any input brings you back
// (hypridle's on-resume hides it; a click or mouse move here does too).
//   qs ipc call idlescreen enter | leave   ("show" is reserved by the qs CLI)
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: idle
    required property ShellScreen modelData
    screen: modelData

    property bool shown: false
    property real phase: 0          // drives the slow drift

    WlrLayershell.namespace: "quickshell-idle"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    function show() {
        if (shown) return
        shown = true
        fadeOut.stop()
        visible = true
        fadeIn.restart()
    }
    function hide() {
        if (!shown) return
        shown = false
        fadeIn.stop()
        fadeOut.restart()
    }

    IpcHandler {
        target: "idlescreen"
        function enter(): void { idle.show() }
        function leave(): void { idle.hide() }
    }

    // Slow drift: 10 updates a second (cheap), only while visible
    Timer {
        running: idle.visible
        interval: 100
        repeat: true
        onTriggered: idle.phase += 0.0025
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        clip: true

        Rectangle { anchors.fill: parent; color: Theme.base }

        // Two very large, soft radial glows drifting on slow circles
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: idle.width * (0.15 + 0.22 * Math.sin(idle.phase * 2.1))
                    centerY: idle.height * (0.30 + 0.25 * Math.cos(idle.phase * 1.7))
                    centerRadius: idle.width * 0.75
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.blue.r, Theme.blue.g, Theme.blue.b, 0.60) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                PathRectangle { x: 0; y: 0; width: idle.width; height: idle.height }
            }
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: idle.width * (0.85 + 0.18 * Math.cos(idle.phase * 1.3))
                    centerY: idle.height * (0.80 + 0.18 * Math.sin(idle.phase * 1.9))
                    centerRadius: idle.width * 0.55
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.26) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                PathRectangle { x: 0; y: 0; width: idle.width; height: idle.height }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            SystemClock { id: clock; precision: SystemClock.Minutes }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "HH:mm")
                font.pixelSize: 140
                font.weight: Font.Bold
                color: Theme.text
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: clock.date.toLocaleDateString(Qt.locale("en_GB"), "dddd, d MMMM")
                font.pixelSize: 26
                color: Theme.ice
            }
            Item { width: 1; height: 28 }
            Row {
                visible: Media.hasTrack
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.isPlaying ? Glyphs.music : Glyphs.pause
                    size: 22
                    color: Theme.lightBlue
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Media.label
                    font.pixelSize: 20
                    color: Theme.muted
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, idle.width * 0.5)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: idle.hide()
            onPositionChanged: if (content.opacity > 0.9) idle.hide()
        }
    }

    NumberAnimation { id: fadeIn; target: content; property: "opacity"; to: 1; duration: 1000; easing.type: Easing.InOutCubic }
    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: 250; easing.type: Easing.InOutCubic }
        ScriptAction { script: idle.visible = false }
    }
}

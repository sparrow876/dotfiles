// Horizontal slider, value 0..1. Drag or click to set; mouse wheel steps 5%.
// Emits moved(value) while the user changes it.
import QtQuick
import qs

Item {
    id: root
    property real value: 0
    property bool muted: false
    signal moved(real value)

    implicitHeight: 22
    implicitWidth: 200

    function setFrom(x) { root.moved(Math.max(0, Math.min(1, x / track.width))) }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.overlay

        Rectangle {
            width: Math.max(height, track.width * Math.min(1, root.value))
            height: parent.height
            radius: 3
            color: root.muted ? Theme.muted : Theme.lightBlue
            Behavior on width { enabled: !area.pressed; NumberAnimation { duration: 120 } }
        }
    }
    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: Math.min(1, root.value) * (track.width - width)
        color: root.muted ? Theme.muted : Theme.ice
        scale: area.pressed || area.containsMouse ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: event => root.setFrom(event.x)
        onPositionChanged: event => { if (pressed) root.setFrom(event.x) }
        WheelSteps { id: wheel }
        onWheel: event => {
            const n = wheel.steps(event)
            if (n) root.moved(Math.max(0, Math.min(1, root.value + 0.05 * n)))
        }
    }
}

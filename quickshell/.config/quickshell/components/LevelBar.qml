// Tiny horizontal level indicator (0..1), e.g. the volume next to the speaker.
import QtQuick
import qs

Rectangle {
    id: root
    property real value: 0
    property bool dimmed: false
    implicitWidth: 34
    implicitHeight: 5
    radius: height / 2
    color: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9)

    Rectangle {
        height: parent.height
        width: Math.max(root.value > 0 ? height : 0, parent.width * Math.min(1, root.value))
        radius: height / 2
        color: root.dimmed ? Theme.muted : Theme.lightBlue
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuint } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}

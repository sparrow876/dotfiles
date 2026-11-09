// On/off switch. `checked` is the state; emits toggled() on click (the owner
// decides whether to flip `checked`, so it always mirrors the real state).
import QtQuick
import qs

MouseArea {
    id: root
    property bool checked: false
    signal toggled()

    implicitWidth: 42
    implicitHeight: 24
    cursorShape: Qt.PointingHandCursor
    onClicked: toggled()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.lightBlue : Theme.overlay
        Behavior on color { ColorAnimation { duration: 160 } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.base : Theme.muted
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
        }
    }
}

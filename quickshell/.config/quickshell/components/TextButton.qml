// Small rounded text button. primary = light-blue fill, danger = red text.
import QtQuick
import qs

MouseArea {
    id: root
    property string label: ""
    property bool primary: false
    property bool danger: false

    implicitWidth: text.implicitWidth + 24
    implicitHeight: 32
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    opacity: enabled ? 1 : 0.5

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.primary ? (root.containsMouse ? Theme.ice : Theme.lightBlue)
                            : (root.containsMouse ? Theme.overlay : Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.5))
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    StyledText {
        id: text
        anchors.centerIn: parent
        text: root.label
        font.pixelSize: Theme.fontSizeSmall + 1
        font.weight: Font.Medium
        color: root.primary ? Theme.base : root.danger ? Theme.critical : Theme.text
    }
}

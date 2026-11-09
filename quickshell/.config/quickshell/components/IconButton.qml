// Round button with a glyph; highlights on hover. Optional tooltip text.
import QtQuick
import qs

MouseArea {
    id: root
    property string glyph: ""
    property real size: 18
    property color color: Theme.text
    property string tooltip: ""

    implicitWidth: size + 12
    implicitHeight: size + 12
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.containsMouse ? Theme.overlay : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Icon {
        anchors.centerIn: parent
        text: root.glyph
        size: root.size
        color: root.color
    }
    Tooltip { target: root; text: root.tooltip }
}

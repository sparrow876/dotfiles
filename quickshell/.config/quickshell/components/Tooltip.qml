// Small frosted tooltip shown under `target` after hovering for a moment.
// Usage:  Tooltip { target: someMouseArea; text: "..." }   (target needs hoverEnabled)
import QtQuick
import Quickshell
import qs

PopupWindow {
    id: tip
    required property Item target
    property string text: ""
    property bool hovered: target.containsMouse ?? false

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 10
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12
    color: "transparent"
    visible: false

    Timer {
        id: delay
        interval: 450
        onTriggered: tip.visible = tip.text.length > 0
    }
    onHoveredChanged: {
        if (hovered) delay.restart()
        else { delay.stop(); visible = false }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)
        StyledText {
            id: label
            anchors.centerIn: parent
            text: tip.text
            font.pixelSize: 12
        }
    }
}

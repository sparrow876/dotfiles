// A clickable status glyph in the bar. Turns light blue while its popup is open.
import QtQuick
import qs
import qs.components
import qs.services

MouseArea {
    id: root
    property string glyph: ""
    property string tooltip: ""
    property string popup: ""          // name of the popup this icon opens
    property string screenName: ""
    property color color: Theme.text
    readonly property bool open: Popups.isOpen(popup, screenName)

    implicitWidth: 22
    implicitHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: event => { if (event.button === Qt.LeftButton && popup) Popups.toggle(popup, screenName) }

    Icon {
        anchors.centerIn: parent
        text: root.glyph
        color: root.open ? Theme.lightBlue : root.color
    }
    Tooltip { target: root; text: root.open ? "" : root.tooltip }
}

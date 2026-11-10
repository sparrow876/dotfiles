// A clickable status glyph in the bar. Turns light blue while its popup is open.
// Extra items (e.g. the volume level bar) can be placed after the glyph:
//   BarIcon { glyph: ...; LevelBar { ... } }
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
    property real glyphSize: 18
    property bool badge: false         // small light-blue dot (e.g. "connected")
    default property alias extra: extraRow.data
    readonly property bool open: popup !== "" && Popups.isOpen(popup, screenName)

    implicitWidth: row.implicitWidth + 4
    implicitHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: event => { if (event.button === Qt.LeftButton && popup) Popups.toggle(popup, screenName) }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Item {
            width: glyphText.implicitWidth
            height: root.implicitHeight
            Icon {
                id: glyphText
                anchors.centerIn: parent
                text: root.glyph
                size: root.glyphSize
                color: root.open ? Theme.lightBlue : root.color
            }
            Rectangle {
                visible: root.badge
                width: 6; height: 6; radius: 3
                color: Theme.lightBlue
                border.width: 1
                border.color: Theme.surface
                anchors.right: glyphText.right
                anchors.rightMargin: -3
                anchors.bottom: glyphText.bottom
                anchors.bottomMargin: 1
            }
        }
        Row {
            id: extraRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }
    }
    Tooltip { target: root; text: root.open ? "" : root.tooltip }
}

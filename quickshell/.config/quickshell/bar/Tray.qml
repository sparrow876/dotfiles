// System tray (StatusNotifierItem apps: ProtonVPN, Steam, Teams, Discord, Claude...).
// Left click: activate (or open the menu if the app only has a menu)
// Right click: themed app menu (TrayMenu.qml)   Middle click: secondary action
// Scroll: forwarded to the app
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.components

Row {
    id: root
    required property var barWindow
    spacing: 10
    visible: SystemTray.items.values.length > 0

    TrayMenu {
        id: menu
        barWindow: root.barWindow
    }

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: slot
            required property SystemTrayItem modelData
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            IconImage {
                anchors.fill: parent
                source: slot.modelData.icon
                implicitSize: 20
                mipmap: true
                opacity: slot.containsMouse ? 1 : 0.9
            }

            onClicked: event => {
                const item = slot.modelData
                if (event.button === Qt.LeftButton) {
                    if (item.onlyMenu && item.hasMenu) menu.toggle(item, slot)
                    else item.activate()
                } else if (event.button === Qt.RightButton) {
                    if (item.hasMenu) menu.toggle(item, slot)
                } else {
                    item.secondaryActivate()
                }
            }
            WheelSteps { id: wheel }
            onWheel: event => { const n = wheel.steps(event); if (n) slot.modelData.scroll(n, false) }

            Tooltip {
                target: slot
                text: slot.modelData.tooltipTitle || slot.modelData.title || slot.modelData.id
            }
        }
    }
}

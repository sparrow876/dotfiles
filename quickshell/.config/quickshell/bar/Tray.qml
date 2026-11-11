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
            // Pomoclock draws its tray icon as a wide pill (170x27), so it gets
            // a slot about six icons wide instead of the usual 20x20 square.
            readonly property bool wide: modelData.id === "io.github.pomoclock.Pomoclock"
            width: wide ? 170 : 20
            height: wide ? 27 : 20
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor

            IconImage {
                visible: !slot.wide
                anchors.fill: parent
                source: slot.wide ? "" : slot.modelData.icon
                implicitSize: 20
                mipmap: true
                opacity: slot.containsMouse ? 1 : 0.9
            }

            // IconImage always requests a square image (and Quickshell scales
            // tray pixmaps to the requested size, ignoring aspect), so the wide
            // pill uses a plain Image that requests its true 170x27 shape.
            Image {
                visible: slot.wide
                anchors.fill: parent
                source: slot.wide ? slot.modelData.icon : ""
                sourceSize: Qt.size(170, 27)
                smooth: true
                cache: false
                opacity: slot.containsMouse ? 1 : 0.95
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

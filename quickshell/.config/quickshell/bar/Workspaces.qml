// Workspaces 一..六 (all six always exist; persistent rule in hypr/conf/rules.lua).
// - active: light-blue pill that slides between workspaces
// - occupied (has windows): white, empty: muted
// - click switches, mouse wheel / touchpad scroll cycles through 1-6
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components

Item {
    id: root
    required property ShellScreen screen

    readonly property var names: ["一", "二", "三", "四", "五", "六"]
    readonly property int cellWidth: 32
    readonly property int spacing: 2
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property int activeIndex: Math.max(0, Math.min(5, activeId - 1))

    implicitWidth: names.length * cellWidth + (names.length - 1) * spacing
    implicitHeight: 28

    function workspace(id) {
        for (const ws of Hyprland.workspaces.values)
            if (ws.id === id) return ws
        return null
    }

    function go(id) {
        const ws = workspace(id)
        if (ws) ws.activate()
    }

    // Sliding pill behind the active workspace (hidden on special workspaces > 6)
    Rectangle {
        id: pill
        y: (root.height - height) / 2
        x: root.activeIndex * (root.cellWidth + root.spacing)
        width: root.cellWidth
        height: 26
        radius: height / 2
        color: Theme.lightBlue
        opacity: root.activeId >= 1 && root.activeId <= 6 ? 1 : 0
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutQuint } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    Row {
        spacing: root.spacing
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.names.length

            delegate: MouseArea {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool active: root.activeId === wsId
                // Re-evaluated whenever Hyprland's window list changes
                readonly property bool occupied: {
                    Hyprland.toplevels.values;
                    const ws = root.workspace(wsId);
                    return ws !== null && ws.toplevels.values.length > 0;
                }

                width: root.cellWidth
                height: root.implicitHeight
                cursorShape: Qt.PointingHandCursor
                onClicked: root.go(wsId)

                StyledText {
                    anchors.centerIn: parent
                    text: root.names[cell.index]
                    font.family: Theme.fontCjk
                    font.pixelSize: 14
                    font.weight: cell.active ? Font.Bold : Font.Medium
                    color: cell.active ? Theme.base : (cell.occupied ? Theme.text : Theme.muted)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
    }

    // Scroll to cycle (accumulates touchpad deltas so one swipe = one step)
    WheelHandler {
        property real accumulated: 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            accumulated += event.angleDelta.y
            if (Math.abs(accumulated) < 120) return
            const step = accumulated > 0 ? -1 : 1
            accumulated = 0
            const next = ((root.activeId - 1 + step + 6) % 6) + 1
            root.go(next)
        }
    }
}

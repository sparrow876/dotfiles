// The top bar: a floating, rounded, frosted strip 8px from the top and 12px
// from the sides. Hyprland blurs everything behind it (layer rule for the
// "quickshell" namespace in hypr/conf/rules.lua).
//
//   left:   workspaces 一 二 三 四 五 六
//   center: music + cava wave (step 8)
//   right:  tray · recording · idle · Wi-Fi · Bluetooth · audio · battery · bell · clock
//           (recording/idle arrive in step 6, bell in step 7)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
    id: bar
    required property ShellScreen modelData
    screen: modelData

    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    anchors { top: true; left: true; right: true }
    margins { top: 8; left: 12; right: 12 }
    implicitHeight: 44
    color: "transparent"

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Theme.rounding
        color: Theme.glass
        border.width: 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)

        Workspaces {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.screen
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Tray { barWindow: bar }
            RowLayout {
                spacing: 10
                NetworkIcon { barWindow: bar }
                BluetoothIcon { barWindow: bar }
                AudioIcon { barWindow: bar }
            }
            Battery {}
            Clock { barWindow: bar }
        }
    }
}

// The top bar: a floating, rounded, frosted strip 8px from the top and 12px
// from the sides. Hyprland blurs everything behind it (layer rule for the
// "quickshell" namespace in hypr/conf/rules.lua).
//
//   left:   workspaces 一 二 三 四 五 六
//   center: music + cava wave (step 8)
//   right:  tray · recording · idle · Wi-Fi · Bluetooth · audio · battery · bell · clock
//           (recording arrives in step 12)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components

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

    // The Wayland idle inhibitor, attached to this bar's surface (hypridle obeys it)
    IdleInhibitor {
        window: bar
        enabled: IdleInhibit.enabled
    }

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
            spacing: 12

            Tray { id: tray; barWindow: bar }
            Separator { visible: tray.visible }
            IdleInhibitIcon {}
            Separator {}
            NetworkIcon { barWindow: bar }
            Separator {}
            BluetoothIcon { id: bt; barWindow: bar }
            Separator { visible: bt.visible }
            AudioIcon { barWindow: bar }
            Separator {}
            Battery { id: battery }
            Separator { visible: battery.visible }
            Bell { barWindow: bar }
            Separator {}
            Clock { barWindow: bar }
        }
    }
}

// The top bar: a floating, rounded, frosted strip 8px from the top and 12px
// from the sides. Hyprland blurs everything behind it (layer rule for the
// "quickshell" namespace in hypr/conf/rules.lua).
//
//   left:   workspaces 一 二 三 四 五 六
//   center: music (artist — title, play/pause)
//   right:  recording · brightness · tray (Pomoclock last) · idle · Wi-Fi ·
//           Bluetooth · audio · battery · bell · clock
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
            id: workspaces
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.screen
        }

        MediaModule {
            anchors.centerIn: parent
            // Centered, so it may use twice the smaller gap to its neighbours
            // (keeps a long title from running under the tray / icons)
            maxWidth: 2 * Math.min(background.width / 2 - (workspaces.x + workspaces.width),
                                   rightGroup.x - background.width / 2) - 40
        }

        RowLayout {
            id: rightGroup
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            RecordingIcon { id: recording; barWindow: bar }
            Separator { visible: recording.visible }
            BrightnessIcon { id: brightness; barWindow: bar }
            Separator { visible: brightness.visible }
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

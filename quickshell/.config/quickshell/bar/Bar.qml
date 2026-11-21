// The top bar: a floating, rounded, frosted strip 8px from the top and 12px
// from the sides; in the compact layout mode (services/LayoutMode.qml, ALT + G)
// a flat, square, slimmer strip on the top edge. Hyprland blurs everything
// behind it (layer rule for the "quickshell" namespace in hypr/conf/rules.lua).
//
//   left:   workspaces 一 二 三 四 五 六 七 八 九
//   center: music (artist — title, play/pause)
//   right:  tray (drag to reorder, Pomoclock last) · layout mode · idle · recording · Wi-Fi ·
//           Bluetooth · audio · brightness · battery · bell · clock
// The music sits in the middle when there's room, otherwise it slides into the
// free space between the workspaces and the tray and uses all of it.
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
    margins {
        top: LayoutMode.compact ? 0 : 8
        left: LayoutMode.compact ? 0 : 12
        right: LayoutMode.compact ? 0 : 12
    }
    implicitHeight: LayoutMode.compact ? 36 : 44
    color: "transparent"

    // The Wayland idle inhibitor, attached to this bar's surface (hypridle obeys it)
    IdleInhibitor {
        window: bar
        enabled: IdleInhibit.enabled
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: LayoutMode.compact ? 0 : Theme.rounding
        // "Deep glacier", mirrored: teal -> steel blue -> navy (centre) ->
        // steel blue -> teal (colours in Theme.qml).
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.00; color: Theme.barEdge }
            GradientStop { position: 0.26; color: Theme.barMid }
            GradientStop { position: 0.50; color: Theme.barCentre }
            GradientStop { position: 0.74; color: Theme.barMid }
            GradientStop { position: 1.00; color: Theme.barEdge }
        }
        border.width: LayoutMode.compact ? 0 : 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)

        Workspaces {
            id: workspaces
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.screen
        }

        MediaModule {
            id: media
            barWindow: bar
            readonly property real gapLeft: workspaces.x + workspaces.width + 24
            readonly property real gapRight: rightGroup.x - 24
            anchors.verticalCenter: parent.verticalCenter
            maxWidth: Math.max(0, gapRight - gapLeft)
            // centred on the bar if it fits, else pushed into the free gap
            x: Math.max(gapLeft, Math.min(background.width / 2 - width / 2, gapRight - width))
        }

        RowLayout {
            id: rightGroup
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Tray { id: tray; barWindow: bar }
            Separator { visible: tray.visible }
            LayoutIcon {}
            IdleInhibitIcon {}
            Separator {}
            RecordingIcon { id: recording; barWindow: bar }
            Separator { visible: recording.visible }
            NetworkIcon { barWindow: bar }
            Separator {}
            BluetoothIcon { id: bt; barWindow: bar }
            Separator { visible: bt.visible }
            AudioIcon { barWindow: bar }
            Separator {}
            BrightnessIcon { id: brightness; barWindow: bar }
            Separator { visible: brightness.visible }
            Battery { id: battery }
            Separator { visible: battery.visible }
            Bell { barWindow: bar }
            Separator {}
            Clock { barWindow: bar }
        }
    }
}

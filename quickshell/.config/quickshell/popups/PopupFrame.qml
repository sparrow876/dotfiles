// Shared frame for every bar popup: anchored under its bar icon, frosted,
// rounded, fades + slides in. Closes on Esc, a click outside, re-clicking the
// icon, or opening another popup (Popups.qml keeps one open at a time).
//
//   PopupFrame { name: "network"; barWindow: bar; anchorItem: icon; ...content... }
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services

PopupWindow {
    id: frame
    required property string name
    required property var barWindow
    property Item anchorItem: null
    property int contentWidth: 360
    default property alias content: body.data
    readonly property bool shouldShow: Popups.isOpen(name, barWindow.screen?.name ?? "")
    signal opened()

    anchor.window: barWindow
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.Slide
    anchor.margins.top: 18
    implicitWidth: contentWidth
    implicitHeight: body.implicitHeight + 28
    color: "transparent"
    grabFocus: Popups.byClick
    visible: false

    // Opened by a keybind/IPC: no grabbing popup possible, so let Hyprland close
    // it on an outside click instead (the keybind toggles it closed too).
    HyprlandFocusGrab {
        active: frame.visible && frame.shouldShow && !Popups.byClick
        windows: [frame]
        onCleared: Popups.close()
    }

    onShouldShowChanged: {
        if (shouldShow) {
            outAnim.stop()
            visible = true
            inAnim.restart()
            panel.forceActiveFocus()
            opened()
        } else if (visible) {
            outAnim.restart()
        }
    }
    // The compositor closes the popup on an outside click; keep state in sync.
    onVisibleChanged: if (!visible && shouldShow) Popups.close()

    Rectangle {
        id: panel
        width: parent.width
        height: parent.height
        radius: Theme.rounding
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.88)
        border.width: 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)
        opacity: 0
        transform: Translate { id: slide; y: -8 }
        focus: true
        Keys.onEscapePressed: Popups.close()

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
        }
    }

    ParallelAnimation {
        id: inAnim
        NumberAnimation { target: panel; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutQuint }
        NumberAnimation { target: slide; property: "y"; to: 0; duration: 220; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: outAnim
        ParallelAnimation {
            NumberAnimation { target: panel; property: "opacity"; to: 0; duration: 130; easing.type: Easing.InOutCubic }
            NumberAnimation { target: slide; property: "y"; to: -6; duration: 130; easing.type: Easing.InOutCubic }
        }
        ScriptAction { script: frame.visible = false }
    }
}

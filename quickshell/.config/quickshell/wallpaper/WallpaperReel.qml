// Wallpaper reel (ALT + W): full-screen overlay (screen blurred + dimmed) with a
// horizontal reel of parallelogram cards leaning 18°. The focused card is wide,
// bright and outlined light blue; neighbours are narrower and dimmer; the reel
// fades out towards the screen edges. Moving glides with easeOutQuint.
//   ←/→, H/L, mouse wheel or click: move · Enter (or click the focused card): apply
//   Esc or clicking the background: close
// Applying uses awww's wipe at the same 18° angle (scripts/wallpaper.sh).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PanelWindow {
    id: reel
    required property ShellScreen modelData
    screen: modelData

    property bool open: false
    property real pos: 0                  // animated focus position (card index)
    property int target: 0                // index we're moving to
    readonly property var files: Wallpapers.files
    readonly property real lean: 0.3249   // tan(18°)
    readonly property int cardH: 380
    readonly property int wideW: 600
    readonly property int narrowW: 270

    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    Behavior on pos { id: posAnim; NumberAnimation { duration: 380; easing.type: Easing.OutQuint } }

    function show() {
        Popups.close()
        Wallpapers.refresh()
        const i = Math.max(0, files.indexOf(Wallpapers.current))
        posAnim.enabled = false
        target = i
        pos = i
        posAnim.enabled = true
        open = true
        hideAnim.stop()
        visible = true
        showAnim.restart()
        keys.forceActiveFocus()
    }
    function close() {
        if (!open) return
        open = false
        Overlays.closed("wallpaper", screen.name)
        showAnim.stop()
        hideAnim.restart()
    }
    // Opened/closed through services/Overlays.qml (keybind -> IPC -> the
    // focused monitor's overlay). A signal handler, not a binding: close()
    // writes back to Overlays.
    Connections {
        target: Overlays
        function onWallpaperChanged() { Overlays.wallpaper === reel.screen.name ? reel.show() : reel.close() }
    }
    function move(step) {
        if (files.length === 0) return
        target = Math.max(0, Math.min(files.length - 1, target + step))
        pos = target
    }
    function apply() {
        if (files.length === 0) return
        Wallpapers.apply(files[target])
        close()
    }

    // When the list loads after opening, jump to the current wallpaper
    Connections {
        target: Wallpapers
        function onFilesChanged() {
            if (!reel.open) return
            const i = Math.max(0, reel.files.indexOf(Wallpapers.current))
            posAnim.enabled = false
            reel.target = i
            reel.pos = i
            posAnim.enabled = true
        }
    }


    // Dim tint over the blurred screen; click closes
    Rectangle {
        id: tint
        anchors.fill: parent
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.45)
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: reel.close() }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape: reel.close(); break
            case Qt.Key_Left: case Qt.Key_H: reel.move(-1); break
            case Qt.Key_Right: case Qt.Key_L: case Qt.Key_Tab: reel.move(1); break
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: reel.apply(); break
            case Qt.Key_Home: reel.move(-reel.files.length); break
            case Qt.Key_End: reel.move(reel.files.length); break
            }
            event.accepted = true
        }
    }

    WheelHandler {
        property real acc: 0
        onWheel: event => {
            acc += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (Math.abs(acc) < 120) return
            reel.move(acc > 0 ? -1 : 1)
            acc = 0
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: 0

        // Empty folder
        Column {
            visible: reel.files.length === 0
            anchors.centerIn: parent
            spacing: 8
            Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "󰸉"; size: 48; color: Theme.muted }
            StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: "No wallpapers yet"; font.weight: Font.Bold }
            StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: "Add .jpg, .png or .webp files to ~/Pictures/Wallpapers"; color: Theme.muted }
        }

        Repeater {
            model: reel.files
            delegate: Item {
                id: card
                required property string modelData
                required property int index
                readonly property real d: index - reel.pos                  // distance from focus
                readonly property real ad: Math.abs(d)
                readonly property real near: Math.max(0, 1 - ad)            // 1 = focused
                readonly property real centerX: reel.width / 2 + d * 300 + Math.sign(d) * Math.min(ad, 1) * 160
                readonly property real edgeFade: 1 - Math.max(0, Math.min(1, (Math.abs(centerX - reel.width / 2) - reel.width * 0.30) / (reel.width * 0.18)))

                visible: ad < 4.5 && edgeFade > 0
                width: reel.narrowW + (reel.wideW - reel.narrowW) * near
                height: reel.cardH
                x: centerX - width / 2
                y: reel.height / 2 - height / 2 - 20
                z: 10 - ad
                opacity: edgeFade

                // Lean the card 18° (top to the right) around its centre
                transform: Matrix4x4 {
                    matrix: Qt.matrix4x4(1, -reel.lean, 0, reel.lean * card.height / 2,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         0, 0, 0, 1)
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Theme.surface

                    // The picture, sheared back so it stays upright inside the leaning card
                    Image {
                        width: parent.width + reel.lean * parent.height
                        height: parent.height
                        x: -reel.lean * parent.height / 2
                        source: Wallpapers.thumb(card.modelData)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 720
                        sourceSize.height: 405
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, reel.lean, 0, -reel.lean * card.height / 2,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }
                    }
                    // Neighbours are dimmed
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.base
                        opacity: 0.55 * Math.min(1, card.ad)
                    }
                }
                // Outline: light blue on the focused card, faint otherwise
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: "transparent"
                    border.width: card.near > 0.5 ? 3 : 1
                    border.color: card.near > 0.5 ? Theme.lightBlue : Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.15)
                }
                // Current wallpaper marker
                Rectangle {
                    visible: card.modelData === Wallpapers.current
                    width: 10; height: 10; radius: 5
                    color: Theme.lightBlue
                    border.width: 2
                    border.color: Theme.base
                    x: parent.width - 24; y: 14
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.index === reel.target) reel.apply()
                        else reel.move(card.index - reel.target)
                    }
                }
            }
        }

        // File name under the focused card
        StyledText {
            visible: reel.files.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: reel.height / 2 + reel.cardH / 2 + 4
            text: reel.files[reel.target] ?? ""
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall + 1
        }
        StyledText {
            visible: reel.files.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 48
            text: "←/→ move · Enter apply · Esc close"
            color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.7)
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: tint; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuint }
        NumberAnimation { target: stage; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: tint; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InOutCubic }
            NumberAnimation { target: stage; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InOutCubic }
        }
        ScriptAction { script: reel.visible = false }
    }
}

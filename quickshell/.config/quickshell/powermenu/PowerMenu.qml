// Power menu (ALT + Escape): the whole screen blurs behind a soft dark tint,
// a greeting + uptime, and a row of large tiles that pop in one after another:
//   Lock (L) · Suspend (S) · Logout (E) · Reboot (R) · Shutdown (P) · BIOS (B)
// ←/→ (or H / Tab) move, Enter / click activates, letters jump straight to an
// action (L is Lock, so it doesn't move right),
// Esc or clicking the background closes.
// Logout / Reboot / Shutdown / BIOS ask for confirmation: the first press starts
// a 3 s countdown on the tile; press again to do it now, Esc to cancel.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: menu
    required property ShellScreen modelData
    screen: modelData

    property bool open: false
    property int selected: 0
    property int pending: -1          // index of the action counting down
    property int countdown: 0
    property real uptime: 0

    readonly property string home: Quickshell.env("HOME")
    readonly property var actions: [
        { name: "Lock",     key: "L", glyph: "󰌾", confirm: false, cmd: [home + "/dotfiles/scripts/lock.sh"] },
        { name: "Suspend",  key: "S", glyph: "󰤄", confirm: false, cmd: ["systemctl", "suspend"] },
        { name: "Logout",   key: "E", glyph: "󰍃", confirm: true,  cmd: [home + "/dotfiles/scripts/logout.sh"] },
        { name: "Reboot",   key: "R", glyph: "󰜉", confirm: true,  cmd: ["systemctl", "reboot"] },
        { name: "Shutdown", key: "P", glyph: "󰐥", confirm: true,  cmd: ["systemctl", "poweroff"] },
        { name: "BIOS",     key: "B", glyph: "󰘚", confirm: true,  cmd: ["systemctl", "reboot", "--firmware-setup"] }
    ]

    WlrLayershell.namespace: "quickshell-powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    function show() {
        Popups.close()
        selected = 0
        cancel()
        uptimeFile.reload()
        greeting = makeGreeting()
        open = true
        hideAnim.stop()
        visible = true
        showAnim.restart()
        keys.forceActiveFocus()
    }
    function close() {
        if (!open) return
        open = false
        Overlays.closed("powermenu", screen.name)
        cancel()
        showAnim.stop()
        hideAnim.restart()
    }
    // Opened/closed through services/Overlays.qml (keybind -> IPC -> the
    // focused monitor's overlay). A signal handler, not a binding: close()
    // writes back to Overlays.
    Connections {
        target: Overlays
        function onPowermenuChanged() { Overlays.powermenu === menu.screen.name ? menu.show() : menu.close() }
    }

    function cancel() { pending = -1; countdownTimer.stop() }
    function run(i) {
        const a = actions[i]
        close()
        // let the menu fade out before locking/suspending
        runTimer.cmd = a.cmd
        runTimer.restart()
    }
    function activate(i) {
        selected = i
        const a = actions[i]
        if (!a.confirm || pending === i) { run(i); return }
        pending = i
        countdown = 3
        countdownTimer.restart()
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            menu.countdown--
            if (menu.countdown <= 0) { stop(); menu.run(menu.pending) }
        }
    }
    Timer {
        id: runTimer
        property var cmd: []
        interval: 220
        onTriggered: Quickshell.execDetached(cmd)
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: menu.uptime = parseFloat(text())
    }


    // Set each time the menu opens (a binding on new Date() would never update)
    property string greeting: ""
    function makeGreeting() {
        const h = new Date().getHours()
        const name = Quickshell.env("USER") || ""
        const part = h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : h < 22 ? "Good evening" : "Good night"
        return `${part}, ${name}`
    }
    function upText(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return "up " + (d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`)
    }

    // Background: dark tint over the (blurred) screen; click closes
    Rectangle {
        id: tint
        anchors.fill: parent
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.35)
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: menu.close() }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Escape) { menu.pending >= 0 ? menu.cancel() : menu.close() }
            else if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab) { menu.cancel(); menu.selected = (menu.selected + 5) % 6 }
            else if (k === Qt.Key_Right || k === Qt.Key_Tab) { menu.cancel(); menu.selected = (menu.selected + 1) % 6 }
            // Activation ignores key auto-repeat: holding Enter / R must not count
            // as the confirming second press (it would reboot without the countdown)
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) { if (!event.isAutoRepeat) menu.activate(menu.selected) }
            else {
                const letter = event.text.toUpperCase()
                const i = menu.actions.findIndex(a => a.key === letter)
                if (i >= 0 && !event.isAutoRepeat) {
                    if (i !== menu.pending) menu.cancel()
                    menu.activate(i)
                }
            }
            event.accepted = true
        }
    }

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        spacing: 28
        opacity: 0

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: menu.greeting
                font.pixelSize: 30
                font.weight: Font.Bold
                color: Theme.text
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: menu.upText(menu.uptime)
                color: Theme.muted
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            Repeater {
                model: menu.actions
                delegate: MouseArea {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: menu.selected === index
                    readonly property bool isPending: menu.pending === index
                    width: 150
                    height: 170
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: { if (menu.pending !== index) menu.cancel(); menu.selected = index }
                    onClicked: menu.activate(index)

                    // staggered pop-in
                    opacity: 0
                    scale: 0.85
                    Connections {
                        target: menu
                        function onOpenChanged() {
                            if (menu.open) { tile.opacity = 0; tile.scale = 0.85; popIn.restart() }
                        }
                    }
                    SequentialAnimation {
                        id: popIn
                        PauseAnimation { duration: 40 + tile.index * 45 }
                        ParallelAnimation {
                            NumberAnimation { target: tile; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutQuint }
                            NumberAnimation { target: tile; property: "scale"; to: 1; duration: 280; easing.type: Easing.OutQuint }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 24
                        color: tile.isPending ? Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.22)
                             : tile.isSelected ? Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.22)
                             : Theme.glass
                        border.width: tile.isSelected || tile.isPending ? 2 : 1
                        border.color: tile.isPending ? Theme.critical
                                    : tile.isSelected ? Theme.lightBlue
                                    : Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)
                        scale: tile.isSelected ? 1.04 : 1
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10
                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.glyph
                            size: 46
                            color: tile.isPending ? Theme.critical : tile.isSelected ? Theme.lightBlue : Theme.text
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.isPending ? `${tile.modelData.name} in ${menu.countdown}…` : tile.modelData.name
                            font.weight: Font.Bold
                            color: tile.isPending ? Theme.critical : Theme.text
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.isPending ? "press again · Esc cancels" : tile.modelData.key
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: tint; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuint }
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: tint; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InOutCubic }
            NumberAnimation { target: content; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InOutCubic }
        }
        ScriptAction { script: menu.visible = false }
    }
}

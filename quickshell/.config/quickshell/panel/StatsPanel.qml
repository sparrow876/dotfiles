// System stats panel (ALT + S). Slides in from the right over the windows:
// 25% of the screen wide, full height with the bar's margins, frosted, cards.
// Doesn't reserve space. Polls only while open (services/SystemStats.qml).
// Sections without data are hidden. Esc / outside click / ALT + S closes it.
//
//  1 header (clock, host, uptime, kernel)   5 disks (+ read/write speed)
//  2 CPU (ring, cores, 60 s graph, ...)      6 network (up/down graph, totals)
//  3 memory (RAM, swap, graph)               7 battery
//  4 GPUs (Intel iGPU, RTX 3050)             8 top processes (kill with confirm)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: panel
    readonly property string me: Quickshell.env("USER") || ""
    // top cuts user names to 8 characters and marks the cut with "+"
    function isMine(user) { return !!user && (user === me || (user.endsWith("+") && me.startsWith(user.slice(0, -1)))) }
    required property ShellScreen modelData
    screen: modelData

    property bool open: false
    readonly property var s: SystemStats.snap

    WlrLayershell.namespace: "quickshell-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; right: true }
    margins { top: 8; bottom: 8; right: 12 }
    implicitWidth: Math.round(screen.width * 0.25)
    color: "transparent"
    visible: false

    // Only on the focused monitor
    // Opened/closed through services/Overlays.qml (keybind -> IPC -> the
    // focused monitor's overlay). A signal handler, not a binding: close()
    // writes back to Overlays.
    Connections {
        target: Overlays
        function onPanelChanged() { Overlays.panel === panel.screen.name ? panel.show() : panel.close() }
    }
    // Monitor unplugged while the panel is open: stop polling
    Component.onDestruction: if (open) SystemStats.active = false

    function show() {
        open = true
        SystemStats.active = true
        hideAnim.stop()
        visible = true
        showAnim.restart()
        frame.forceActiveFocus()
    }
    function close() {
        if (!open) return
        open = false
        Overlays.closed("panel", screen.name)
        SystemStats.active = false
        procSection.confirmPid = -1
        showAnim.stop()
        hideAnim.restart()
    }

    HyprlandFocusGrab {
        active: panel.open
        windows: [panel]
        onCleared: panel.close()
    }

    // --- colors for warn / critical ------------------------------------------
    function tone(levelName) {
        return levelName === "critical" ? Theme.critical : levelName === "warn" ? Theme.warn : Theme.lightBlue
    }

    Rectangle {
        id: frame
        width: parent.width
        height: parent.height
        radius: Theme.rounding
        color: Theme.glass
        border.width: 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)
        opacity: 0
        transform: Translate { id: slide; x: 40 }
        focus: true
        Keys.onEscapePressed: panel.close()

        Flickable {
            anchors.fill: parent
            anchors.margins: 14
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: content
                width: parent.width
                spacing: 12

                // ---------------------------------------------------- 1 header
                Card {
                    Layout.fillWidth: true
                    padding: 16
                    RowLayout {
                        width: parent.width
                        SystemClock { id: clock; precision: SystemClock.Minutes }
                        StyledText {
                            text: Qt.formatTime(clock.date, "HH:mm")
                            font.pixelSize: 40
                            font.weight: Font.Bold
                            color: Theme.ice
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 10
                            spacing: 2
                            StyledText {
                                text: panel.s?.host ?? ""
                                font.weight: Font.Bold
                            }
                            StyledText {
                                text: panel.s ? "up " + SystemStats.duration(panel.s.uptime) : ""
                                color: Theme.muted
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            StyledText {
                                text: panel.s?.kernel ?? ""
                                color: Theme.muted
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }

                // ------------------------------------------------------- 2 CPU
                Section {
                    title: "CPU"
                    visible: panel.s !== null
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        RingGauge {
                            value: SystemStats.cpu
                            color: panel.tone(SystemStats.level(SystemStats.cpu, 0.85, 0.95))
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            KeyValue {
                                key: "Frequency"
                                value: panel.s?.freq ? `${(panel.s.freq[0] / 1000).toFixed(2)} GHz (max ${(panel.s.freq[1] / 1000).toFixed(2)})` : "–"
                            }
                            KeyValue {
                                key: "Temperature"
                                value: panel.s?.temp != null ? `${Math.round(panel.s.temp)} °C` : "–"
                                valueColor: panel.s?.temp >= 90 ? Theme.critical : panel.s?.temp >= 80 ? Theme.warn : Theme.text
                            }
                            KeyValue {
                                key: "Load"
                                value: panel.s ? panel.s.load.map(v => v.toFixed(2)).join("  ") : "–"
                            }
                        }
                    }
                    // Per-core bars
                    Row {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        spacing: 4
                        Repeater {
                            // a count, not the array: bars stay and animate between polls
                            model: SystemStats.cores.length
                            delegate: Rectangle {
                                required property int index
                                readonly property real modelData: SystemStats.cores[index] ?? 0
                                width: (parent.width - (SystemStats.cores.length - 1) * 4) / Math.max(1, SystemStats.cores.length)
                                height: 34
                                radius: 3
                                color: Theme.overlay
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, parent.height * modelData)
                                    radius: 3
                                    color: panel.tone(SystemStats.level(modelData, 0.85, 0.95))
                                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                                }
                            }
                        }
                    }
                    Graph {
                        Layout.fillWidth: true
                        values: SystemStats.cpuHistory
                        capacity: SystemStats.historyLength
                    }
                }

                // ---------------------------------------------------- 3 memory
                Section {
                    title: "Memory"
                    visible: panel.s !== null
                    LabeledBar {
                        label: "RAM"
                        detail: panel.s ? `${SystemStats.bytes((panel.s.mem.total - panel.s.mem.avail) * 1024)} / ${SystemStats.bytes(panel.s.mem.total * 1024)}` : ""
                        value: SystemStats.mem
                        fillColor: panel.tone(SystemStats.level(SystemStats.mem, 0.85, 0.95))
                    }
                    LabeledBar {
                        visible: (panel.s?.mem.swapTotal ?? 0) > 0
                        label: "Swap"
                        detail: panel.s ? `${SystemStats.bytes((panel.s.mem.swapTotal - panel.s.mem.swapFree) * 1024)} / ${SystemStats.bytes(panel.s.mem.swapTotal * 1024)}` : ""
                        value: SystemStats.swap
                        fillColor: panel.tone(SystemStats.level(SystemStats.swap, 0.5, 0.8))
                    }
                    Graph {
                        Layout.fillWidth: true
                        implicitHeight: 44
                        values: SystemStats.memHistory
                        capacity: SystemStats.historyLength
                        color: Theme.ice
                    }
                }

                // ------------------------------------------------------ 4 GPUs
                Section {
                    title: "Graphics"
                    visible: panel.s !== null && (panel.s.igpu !== null || panel.s.nv !== null)
                    KeyValue {
                        visible: panel.s?.igpu != null
                        key: "Intel iGPU"
                        value: panel.s?.igpu ? `${panel.s.igpu.cur} / ${panel.s.igpu.max} MHz` : ""
                    }
                    KeyValue {
                        visible: panel.s?.nv != null && panel.s.nv.state !== "active"
                        key: "RTX 3050"
                        value: "Asleep (saving power)"
                        valueColor: Theme.muted
                    }
                    ColumnLayout {
                        visible: panel.s?.nv?.state === "active" && panel.s.nv.util !== undefined
                        Layout.fillWidth: true
                        spacing: 6
                        LabeledBar {
                            label: "RTX 3050"
                            detail: panel.s?.nv?.util !== undefined ? `${panel.s.nv.util}% · ${panel.s.nv.clock} MHz` : ""
                            value: (panel.s?.nv?.util ?? 0) / 100
                        }
                        LabeledBar {
                            label: "VRAM"
                            detail: panel.s?.nv?.memTotal ? `${panel.s.nv.memUsed} / ${panel.s.nv.memTotal} MiB` : ""
                            value: panel.s?.nv?.memTotal ? panel.s.nv.memUsed / panel.s.nv.memTotal : 0
                            fillColor: Theme.ice
                        }
                        KeyValue {
                            key: "Temp · power"
                            value: panel.s?.nv?.temp !== undefined ? `${panel.s.nv.temp} °C · ${panel.s.nv.power ?? "–"} W` : ""
                            valueColor: (panel.s?.nv?.temp ?? 0) >= 87 ? Theme.critical : (panel.s?.nv?.temp ?? 0) >= 80 ? Theme.warn : Theme.text
                        }
                    }
                }

                // ----------------------------------------------------- 5 disks
                Section {
                    title: "Disks"
                    visible: (panel.s?.disks?.length ?? 0) > 0
                    Repeater {
                        model: panel.s?.disks ?? []
                        delegate: LabeledBar {
                            required property var modelData
                            label: modelData.mount
                            detail: `${SystemStats.bytes(modelData.used)} / ${SystemStats.bytes(modelData.size)}`
                            value: modelData.size > 0 ? modelData.used / modelData.size : 0
                            fillColor: panel.tone(SystemStats.level(value, 0.9, 0.95))
                        }
                    }
                    KeyValue {
                        visible: panel.s?.diskio != null
                        key: "Read · write"
                        value: `${SystemStats.rate(SystemStats.readRate)} · ${SystemStats.rate(SystemStats.writeRate)}`
                    }
                }

                // --------------------------------------------------- 6 network
                Section {
                    title: "Network"
                    visible: panel.s?.net != null
                    KeyValue {
                        key: panel.s?.net?.iface ?? ""
                        value: Network.summary
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { text: "↓ " + SystemStats.rate(SystemStats.rxRate); color: Theme.lightBlue; font.pixelSize: Theme.fontSizeSmall }
                        Item { Layout.fillWidth: true }
                        StyledText { text: "↑ " + SystemStats.rate(SystemStats.txRate); color: Theme.ice; font.pixelSize: Theme.fontSizeSmall }
                    }
                    Graph {
                        Layout.fillWidth: true
                        values: SystemStats.rxHistory
                        values2: SystemStats.txHistory
                        max: Math.max(64 * 1024, ...SystemStats.rxHistory, ...SystemStats.txHistory)
                        capacity: SystemStats.historyLength
                    }
                    KeyValue {
                        key: "Since boot"
                        value: panel.s?.net ? `↓ ${SystemStats.bytes(panel.s.net.rx)} · ↑ ${SystemStats.bytes(panel.s.net.tx)}` : ""
                    }
                }

                // --------------------------------------------------- 7 battery
                Section {
                    id: batterySection
                    readonly property var dev: Power.display
                    title: "Battery"
                    visible: dev?.isPresent ?? false
                    LabeledBar {
                        label: UPowerDeviceState.toString(batterySection.dev?.state ?? 0)
                        detail: Math.round((batterySection.dev?.percentage ?? 0) * 100) + "%"
                        value: batterySection.dev?.percentage ?? 0
                        fillColor: (batterySection.dev?.percentage ?? 1) < 0.1 && UPower.onBattery ? Theme.critical
                                 : (batterySection.dev?.percentage ?? 1) < 0.2 && UPower.onBattery ? Theme.warn : Theme.lightBlue
                    }
                    KeyValue {
                        key: "Power draw"
                        value: Math.abs(batterySection.dev?.changeRate ?? 0).toFixed(1) + " W"
                    }
                    KeyValue {
                        readonly property real secs: UPower.onBattery ? (batterySection.dev?.timeToEmpty ?? 0) : (batterySection.dev?.timeToFull ?? 0)
                        visible: secs > 0
                        key: UPower.onBattery ? "Time left" : "Full in"
                        value: SystemStats.duration(secs)
                    }
                    KeyValue {
                        // health comes from the real battery (BAT0), not the display device
                        visible: Power.battery?.healthSupported ?? false
                        key: "Health"
                        value: Math.round(Power.battery?.healthPercentage ?? 0) + "%"
                    }
                }

                // ------------------------------------------------- 8 processes
                Section {
                    id: procSection
                    property bool byMemory: false
                    property int confirmPid: -1
                    // Rows hold still while the mouse is over the list or a kill is
                    // armed, so the ✕ / "End process?" never moves onto another process
                    readonly property bool frozen: procHover.hovered || confirmPid !== -1
                    readonly property var live: (byMemory ? panel.s?.procsMem : panel.s?.procsCpu)?.slice(0, 8) ?? []
                    property var rows: []
                    onLiveChanged: if (!frozen || rows.length === 0) rows = live
                    onFrozenChanged: if (!frozen) rows = live
                    onByMemoryChanged: rows = live
                    title: "Processes"
                    visible: (panel.s?.procsCpu?.length ?? 0) > 0

                    HoverHandler { id: procHover }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        TextButton { label: "CPU"; primary: !procSection.byMemory; onClicked: procSection.byMemory = false }
                        TextButton { label: "Memory"; primary: procSection.byMemory; onClicked: procSection.byMemory = true }
                    }

                    Repeater {
                        model: procSection.rows
                        delegate: MouseArea {
                            id: prow
                            required property var modelData
                            readonly property bool confirming: procSection.confirmPid === modelData.pid
                            Layout.fillWidth: true
                            implicitHeight: 32
                            hoverEnabled: true
                            onExited: if (confirming) procSection.confirmPid = -1

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: prow.containsMouse ? Theme.overlay : "transparent"
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 4
                                spacing: 8
                                StyledText {
                                    text: prow.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSizeSmall + 1
                                    Layout.fillWidth: true
                                }
                                StyledText {
                                    visible: !prow.confirming
                                    text: (procSection.byMemory ? prow.modelData.mem : prow.modelData.cpu).toFixed(1) + "%"
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                // Hover -> kill button -> confirm (SIGTERM)
                                IconButton {
                                    // only your own processes, and never the shell itself
                                    visible: prow.containsMouse && !prow.confirming
                                             && panel.isMine(prow.modelData.user)
                                             && !/^(qs|quickshell)$/.test(prow.modelData.name.split(" ")[0])
                                    glyph: Glyphs.close
                                    size: 13
                                    color: Theme.critical
                                    tooltip: `End ${prow.modelData.name} (PID ${prow.modelData.pid})`
                                    onClicked: procSection.confirmPid = prow.modelData.pid
                                }
                                TextButton {
                                    visible: prow.confirming
                                    label: "End process?"
                                    danger: true
                                    onClicked: {
                                        Quickshell.execDetached(["sh", "-c", 'kill -TERM "$1" 2>/dev/null || notify-send -a "System stats" -i dialog-error "Couldn\'t end $2" "It belongs to another user or has already exited."',
                                            "kill", String(prow.modelData.pid), prow.modelData.name])
                                        procSection.confirmPid = -1
                                    }
                                }
                            }
                        }
                    }
                }

                StyledText {
                    visible: panel.s === null
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 40
                    text: "Reading system stats…"
                    color: Theme.muted
                }
            }
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: frame; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuint }
        NumberAnimation { target: slide; property: "x"; to: 0; duration: 240; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: frame; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InOutCubic }
            NumberAnimation { target: slide; property: "x"; to: 40; duration: 180; easing.type: Easing.InOutCubic }
        }
        ScriptAction { script: panel.visible = false }
    }

    // --- small building blocks ------------------------------------------------
    component Section: Card {
        id: sec
        default property alias body: col.data
        property string title
        Layout.fillWidth: true
        padding: 14
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 8
            StyledText { text: sec.title; font.weight: Font.Bold; color: Theme.ice }
        }
    }
    component KeyValue: RowLayout {
        property string key
        property string value
        property color valueColor: Theme.text
        Layout.fillWidth: true
        StyledText { text: parent.key; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall }
        Item { Layout.fillWidth: true }
        StyledText { text: parent.value; color: parent.valueColor; font.pixelSize: Theme.fontSizeSmall; elide: Text.ElideLeft; Layout.maximumWidth: 260 }
    }
    component LabeledBar: ColumnLayout {
        property string label
        property string detail
        property real value
        property color fillColor: Theme.lightBlue
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            StyledText { text: parent.parent.label; font.pixelSize: Theme.fontSizeSmall }
            Item { Layout.fillWidth: true }
            StyledText { text: parent.parent.detail; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall }
        }
        LevelBar {
            Layout.fillWidth: true
            implicitHeight: 7
            value: parent.value
            fillColor: parent.fillColor
        }
    }
}

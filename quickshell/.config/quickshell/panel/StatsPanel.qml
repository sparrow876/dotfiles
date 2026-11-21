// System stats panel (ALT + S), v2. Slides in from the right over the windows:
// 25% of the screen wide, full height with the bar's margins, frosted, cards.
// Doesn't reserve space. Polls only while open (services/SystemStats.qml), and
// every animation below runs only while it's open. Esc / outside click /
// ALT + S closes it. v1 is the git tag `stats-panel-v1`.
// CPU budget: no ambient loops while all is normal (any looping animation makes
// Qt redraw the whole panel at 144 Hz); motion happens in short bursts after
// each poll. Measured ~70% of a core with continuous motion, see MAINTENANCE.
//
//  hero: greeting, live clock + seconds line, soft glows, host/uptime/kernel chips
//  overview: CPU · RAM · GPU · disk rings (ticks, count-up, pulse on alert)
//  processor: tiles (freq, temp + thermometer, load avg), per-thread heat map
//             (hover a thread: its own 60 s graph), 60 s graph
//  memory · graphics · storage · network (peaks, pulsing arrows) · battery
//  (charging shimmer) · processes (app icons, usage bars, CPU/Memory switch)
// Click a section header to collapse it (remembered across restarts).
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets
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
    // cards animate in once the first numbers are there
    readonly property bool revealed: open && s !== null

    WlrLayershell.namespace: "quickshell-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; right: true }
    margins { top: 8; bottom: 8; right: 12 }
    implicitWidth: Math.round(screen.width * 0.25)
    color: "transparent"
    visible: false

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
        scroller.contentY = 0   // always open at the top (the window persists between opens)
        showAnim.restart()
        frame.forceActiveFocus()
    }
    function close() {
        if (!open) return
        open = false
        Overlays.closed("panel", screen.name)
        SystemStats.active = false
        procSection.confirmPid = -1
        hoverCore = -1
        showAnim.stop()
        hideAnim.restart()
    }

    HyprlandFocusGrab {
        active: panel.open
        windows: [panel]
        onCleared: panel.close()
    }

    // --- colors / helpers ------------------------------------------------------
    function tone(levelName) {
        return levelName === "critical" ? Theme.critical : levelName === "warn" ? Theme.warn : Theme.lightBlue
    }
    function pct(v) { return Math.round(Math.max(0, v) * 100) + "%" }

    readonly property bool nvActive: s?.nv?.state === "active" && s.nv.util !== undefined
    readonly property real gpuValue: nvActive ? s.nv.util / 100 : (s?.igpu?.max ? s.igpu.cur / s.igpu.max : 0)
    readonly property var rootDisk: (s?.disks ?? []).find(d => d.mount === "/") ?? (s?.disks?.[0] ?? null)
    readonly property real rootUse: rootDisk && rootDisk.size > 0 ? rootDisk.used / rootDisk.size : 0
    readonly property real temp: s?.temp ?? 0
    readonly property string tempLevel: temp >= 90 ? "critical" : temp >= 80 ? "warn" : "normal"


    // --- panel-local histories (per-thread graphs, network peaks) ------------
    property var coreHistory: []
    property real rxPeak: 0
    property real txPeak: 0
    property int hoverCore: -1
    Connections {
        target: SystemStats
        function onSnapChanged() {
            const s = SystemStats.snap
            if (!s) { panel.coreHistory = []; panel.rxPeak = 0; panel.txPeak = 0 }
        }
        function onCpuHistoryChanged() {
            const c = SystemStats.cores
            panel.coreHistory = c.map((v, i) => SystemStats.push(panel.coreHistory[i] ?? [], v))
            panel.rxPeak = Math.max(0, ...SystemStats.rxHistory)
            panel.txPeak = Math.max(0, ...SystemStats.txHistory)
        }
    }

    // Collapsed sections (by title), saved like the tray order
    FileView {
        path: Quickshell.statePath("stats-panel.json")
        printErrors: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: store
            property var collapsed: []
        }
    }
    function toggleSection(title) {
        const c = store.collapsed
        store.collapsed = c.includes(title) ? c.filter(t => t !== title) : c.concat([title])
    }

    // Process icon: the app's desktop entry icon, else an icon named like the
    // process, else "" (a letter badge is shown instead)
    // Looked up once per name and cached: the fuzzy desktop-entry search on
    // every poll cost ~8% of a core.
    property var iconCache: ({})
    function procIcon(name) {
        const n = (name || "").split(" ")[0].split("/")[0]
        if (!n) return ""
        if (n in iconCache) return iconCache[n]
        const e = DesktopEntries.heuristicLookup(n)
        const path = e && e.icon ? Quickshell.iconPath(e.icon, true) : Quickshell.iconPath(n.toLowerCase(), true)
        iconCache[n] = path || ""
        return iconCache[n]
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
            id: scroller
            anchors.fill: parent
            anchors.margins: 14
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: content
                width: parent.width
                spacing: 12

                // ------------------------------------------------------ hero
                Rectangle {
                    id: hero
                    Layout.fillWidth: true
                    implicitHeight: heroCol.implicitHeight + 32
                    radius: 14
                    clip: true
                    border.width: 1
                    border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.10)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.22) }
                        GradientStop { position: 0.6; color: Qt.rgba(Theme.blue.r, Theme.blue.g, Theme.blue.b, 0.18) }
                        GradientStop { position: 1; color: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.35) }
                    }
                    opacity: panel.open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }

                    // slowly drifting soft glows
                    GlowBlob {
                        id: blobA
                        tint: Theme.lightBlue
                        width: 220; height: 220
                        x: -60; y: -90
                    }
                    GlowBlob {
                        tint: Theme.ice
                        width: 160; height: 160
                        x: hero.width - 120; y: hero.height - 70
                    }
                    // Arch logo watermark
                    StyledText {
                        anchors.right: parent.right
                        anchors.rightMargin: -14
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""   // Arch logo (nf-linux-archlinux, U+F303)
                        font.pixelSize: 132
                        color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.08)
                    }

                    // seconds only tick while the panel is open
                    SystemClock { id: clock; precision: SystemClock.Seconds; enabled: panel.open }
                    ColumnLayout {
                        id: heroCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 16
                        spacing: 2
                        StyledText {
                            readonly property int h: clock.date.getHours()
                            readonly property string name: panel.me ? panel.me.charAt(0).toUpperCase() + panel.me.slice(1) : ""
                            text: (h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : h < 22 ? "Good evening" : "Good night")
                                  + (name ? ", " + name : "")
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        Row {
                            spacing: 2
                            StyledText {
                                text: Qt.formatTime(clock.date, "HH:mm")
                                font.pixelSize: 46
                                font.weight: Font.Bold
                                color: Theme.ice
                            }
                            StyledText {
                                anchors.baseline: parent.children[0].baseline
                                text: Qt.formatTime(clock.date, ":ss")
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.55)
                            }
                        }
                        // seconds of the current minute
                        Rectangle {
                            Layout.preferredWidth: 150
                            implicitHeight: 3
                            radius: 1.5
                            color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)
                            Rectangle {
                                height: parent.height
                                radius: 1.5
                                width: parent.width * clock.date.getSeconds() / 59
                                color: Theme.lightBlue
                            }
                        }
                        StyledText {
                            Layout.topMargin: 6
                            text: Qt.formatDate(clock.date, "dddd, d MMMM")
                            color: Theme.muted
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            spacing: 6
                            HeroChip { glyph: "󰒋"; label: panel.s?.host ?? "" }
                            HeroChip { glyph: "󰥔"; label: panel.s ? "up " + SystemStats.duration(panel.s.uptime) : "" }
                            HeroChip { glyph: ""; label: panel.s?.kernel ?? "" }
                        }
                    }
                }

                // ------------------------------------------- loading skeleton
                Repeater {
                    model: panel.s === null ? 4 : 0
                    delegate: Skeleton {
                        required property int index
                        live: panel.open
                        implicitHeight: [110, 180, 140, 160][index]
                    }
                }

                // -------------------------------------------------- overview
                Section {
                    visible: panel.s !== null
                    shown: panel.revealed
                    order: 1
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        OverviewRing {
                            caption: "CPU"
                            value: SystemStats.cpu
                            detail: panel.s?.temp != null ? `${Math.round(panel.s.temp)} °C` : ""
                            level: SystemStats.level(SystemStats.cpu, 0.85, 0.95)
                            live: panel.open
                        }
                        OverviewRing {
                            caption: "RAM"
                            value: SystemStats.mem
                            detail: panel.s ? SystemStats.bytes((panel.s.mem.total - panel.s.mem.avail) * 1024) : ""
                            level: SystemStats.level(SystemStats.mem, 0.85, 0.95)
                            live: panel.open
                        }
                        OverviewRing {
                            caption: panel.nvActive ? "RTX" : "iGPU"
                            value: panel.gpuValue
                            detail: panel.nvActive ? `${Math.round(panel.s.nv.temp)} °C` : (panel.s?.igpu ? `${panel.s.igpu.cur} MHz` : "")
                            level: SystemStats.level(panel.gpuValue, 0.9, 0.97)
                            live: panel.open
                        }
                        OverviewRing {
                            caption: "Disk"
                            value: panel.rootUse
                            detail: panel.rootDisk ? SystemStats.bytes(panel.rootDisk.size - panel.rootDisk.used) + " free" : ""
                            level: SystemStats.level(panel.rootUse, 0.9, 0.95)
                            live: panel.open
                        }
                    }
                }

                // ------------------------------------------------------- CPU
                Section {
                    title: "Processor"
                    glyph: "󰘚"
                    number: SystemStats.cpu * 100
                    headlineColor: panel.tone(SystemStats.level(SystemStats.cpu, 0.85, 0.95))
                    collapsed: store.collapsed.includes(title)
                    onToggled: panel.toggleSection(title)
                    visible: panel.s !== null
                    shown: panel.revealed
                    order: 2
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Tile {
                            caption: "Frequency"
                            value: panel.s?.freq ? `${(panel.s.freq[0] / 1000).toFixed(2)} GHz` : "–"
                            sub: panel.s?.freq ? `max ${(panel.s.freq[1] / 1000).toFixed(2)}` : ""
                        }
                        Tile {
                            caption: "Temperature"
                            value: panel.s?.temp != null ? `${Math.round(panel.s.temp)} °C` : "–"
                            valueColor: panel.tempLevel === "normal" ? Theme.text : panel.tone(panel.tempLevel)
                            thermo: panel.s?.temp != null ? Math.min(1, Math.max(0, (panel.temp - 30) / 70)) : -1
                        }
                        Tile {
                            // load average: tasks running or waiting for the CPU, averaged
                            // over 1 / 5 / 15 min; below the thread count = keeping up
                            caption: "Load avg (1 min)"
                            value: panel.s ? panel.s.load[0].toFixed(2) : "–"
                            valueColor: panel.s && panel.s.load[0] > SystemStats.cores.length ? Theme.warn : Theme.text
                            sub: panel.s ? `5m ${panel.s.load[1].toFixed(2)}  15m ${panel.s.load[2].toFixed(2)}` : ""
                        }
                    }
                    // Per-thread heat map: one tile per thread, brighter = busier
                    // (warning tones when hot), with the exact percentage
                    Grid {
                        id: coreGrid
                        readonly property int n: SystemStats.cores.length
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        columns: n > 8 ? Math.ceil(n / 2) : Math.max(1, Math.min(n, 4))
                        spacing: 6
                        Repeater {
                            // a count, not the array: tiles stay and animate between polls
                            model: coreGrid.n
                            delegate: Rectangle {
                                id: cell
                                required property int index
                                readonly property real load: Math.min(1, SystemStats.cores[index] ?? 0)
                                readonly property string lvl: SystemStats.level(load, 0.85, 0.95)
                                readonly property color heat: lvl === "normal" ? Theme.lightBlue : panel.tone(lvl)
                                readonly property bool bright: load > 0.55   // dark text on a bright tile
                                readonly property bool picked: panel.hoverCore === index
                                width: (coreGrid.width - (coreGrid.columns - 1) * coreGrid.spacing) / coreGrid.columns
                                height: 44
                                radius: 9
                                color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.35)
                                border.width: picked ? 2 : 1
                                border.color: picked ? Theme.ice : Qt.rgba(cell.heat.r, cell.heat.g, cell.heat.b, 0.10 + 0.45 * cell.load)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: cell.heat
                                    opacity: 0.06 + 0.78 * cell.load
                                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                                Column {
                                    anchors.centerIn: parent
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(cell.load * 100) + "%"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: cell.bright ? Theme.base : Theme.text
                                    }
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "T" + cell.index
                                        font.pixelSize: Theme.fontSizeSmall - 3
                                        color: cell.bright ? Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.75) : Theme.muted
                                    }
                                }
                                HoverHandler {
                                    onHoveredChanged: {
                                        if (hovered) panel.hoverCore = cell.index
                                        else if (panel.hoverCore === cell.index) panel.hoverCore = -1
                                    }
                                }
                            }
                        }
                    }
                    // hovered thread: its own 60 s graph (slides open)
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: panel.hoverCore >= 0 ? 70 : 0
                        visible: implicitHeight > 0   // no empty gap in the layout when closed
                        clip: true
                        Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
                        Rectangle {
                            width: parent.width
                            height: 70
                            radius: 10
                            color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.35)
                            StyledText {
                                x: 10; y: 6
                                text: panel.hoverCore >= 0
                                      ? `Thread T${panel.hoverCore} · ${Math.round((SystemStats.cores[panel.hoverCore] ?? 0) * 100)}% now · last 60 s`
                                      : ""
                                color: Theme.muted
                                font.pixelSize: Theme.fontSizeSmall - 2
                            }
                            Graph {
                                x: 10; y: 24
                                width: parent.width - 20
                                height: 40
                                minimal: true
                                values: panel.hoverCore >= 0 ? (panel.coreHistory[panel.hoverCore] ?? []) : []
                                capacity: SystemStats.historyLength
                                glide: SystemStats.interval
                                color: Theme.ice
                            }
                        }
                    }
                    StyledText {
                        // busiest thread + what the graph below covers
                        readonly property int busiest: SystemStats.cores.reduce((b, v, i, a) => v > a[b] ? i : b, 0)
                        text: SystemStats.cores.length
                              ? `${SystemStats.cores.length} threads · busiest T${busiest} ${Math.round((SystemStats.cores[busiest] ?? 0) * 100)}% · hover a thread for its graph`
                              : ""
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeSmall - 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Graph {
                        Layout.fillWidth: true
                        values: SystemStats.cpuHistory
                        capacity: SystemStats.historyLength
                        glide: SystemStats.interval
                    }
                }

                // ---------------------------------------------------- memory
                Section {
                    title: "Memory"
                    glyph: "󰍛"
                    number: SystemStats.mem * 100
                    headlineColor: panel.tone(SystemStats.level(SystemStats.mem, 0.85, 0.95))
                    collapsed: store.collapsed.includes(title)
                    onToggled: panel.toggleSection(title)
                    visible: panel.s !== null
                    shown: panel.revealed
                    order: 3
                    GBar {
                        label: "RAM"
                        detail: panel.s ? `${SystemStats.bytes((panel.s.mem.total - panel.s.mem.avail) * 1024)} / ${SystemStats.bytes(panel.s.mem.total * 1024)}` : ""
                        value: SystemStats.mem
                        level: SystemStats.level(SystemStats.mem, 0.85, 0.95)
                    }
                    GBar {
                        visible: (panel.s?.mem.swapTotal ?? 0) > 0
                        label: "Swap"
                        detail: panel.s ? `${SystemStats.bytes((panel.s.mem.swapTotal - panel.s.mem.swapFree) * 1024)} / ${SystemStats.bytes(panel.s.mem.swapTotal * 1024)}` : ""
                        value: SystemStats.swap
                        level: SystemStats.level(SystemStats.swap, 0.5, 0.8)
                    }
                    Graph {
                        Layout.fillWidth: true
                        implicitHeight: 46
                        values: SystemStats.memHistory
                        capacity: SystemStats.historyLength
                        glide: SystemStats.interval
                        color: Theme.ice
                    }
                }

                // -------------------------------------------------- graphics
                Section {
                    title: "Graphics"
                    glyph: "󰢮"
                    number: panel.nvActive && panel.s.nv.temp !== undefined ? panel.s.nv.temp : NaN
                    unit: " °C"
                    headlineColor: (panel.s?.nv?.temp ?? 0) >= 87 ? Theme.critical : (panel.s?.nv?.temp ?? 0) >= 80 ? Theme.warn : Theme.lightBlue
                    collapsed: store.collapsed.includes(title)
                    onToggled: panel.toggleSection(title)
                    visible: panel.s !== null && (panel.s.igpu !== null || panel.s.nv !== null)
                    shown: panel.revealed
                    order: 4
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        GpuTile {
                            visible: panel.s?.igpu != null
                            name: "Intel iGPU"
                            value: panel.s?.igpu ? `${panel.s.igpu.cur} MHz` : ""
                            fraction: panel.s?.igpu?.max ? panel.s.igpu.cur / panel.s.igpu.max : 0
                            sub: panel.s?.igpu ? `max ${panel.s.igpu.max} MHz` : ""
                        }
                        GpuTile {
                            visible: panel.s?.nv != null
                            name: "RTX 3050"
                            asleep: !panel.nvActive
                            value: panel.nvActive ? `${panel.s.nv.util}%` : "Asleep"
                            fraction: panel.nvActive ? panel.s.nv.util / 100 : 0
                            sub: panel.nvActive ? `${panel.s.nv.clock} MHz · ${panel.s.nv.power ?? "–"} W` : "saving power"
                        }
                    }
                    GBar {
                        visible: panel.nvActive && !!panel.s.nv.memTotal
                        label: "VRAM"
                        detail: panel.s?.nv?.memTotal ? `${panel.s.nv.memUsed} / ${panel.s.nv.memTotal} MiB` : ""
                        value: panel.s?.nv?.memTotal ? panel.s.nv.memUsed / panel.s.nv.memTotal : 0
                        level: "normal"
                    }
                }

                // ----------------------------------------------------- disks
                Section {
                    title: "Storage"
                    glyph: "󰋊"
                    number: panel.rootDisk ? panel.rootUse * 100 : NaN
                    headlineColor: panel.tone(SystemStats.level(panel.rootUse, 0.9, 0.95))
                    collapsed: store.collapsed.includes(title)
                    onToggled: panel.toggleSection(title)
                    visible: (panel.s?.disks?.length ?? 0) > 0
                    shown: panel.revealed
                    order: 5
                    Repeater {
                        model: panel.s?.disks ?? []
                        delegate: GBar {
                            required property var modelData
                            label: modelData.mount
                            detail: `${SystemStats.bytes(modelData.used)} / ${SystemStats.bytes(modelData.size)}`
                            value: modelData.size > 0 ? modelData.used / modelData.size : 0
                            level: SystemStats.level(value, 0.9, 0.95)
                        }
                    }
                    RowLayout {
                        visible: panel.s?.diskio != null
                        Layout.fillWidth: true
                        spacing: 8
                        Tile {
                            glyph: "󰇚"; caption: "Read"; value: SystemStats.rate(SystemStats.readRate)
                            pulse: SystemStats.readRate > 64 * 1024; live: panel.open
                        }
                        Tile {
                            glyph: "󰕒"; caption: "Write"; value: SystemStats.rate(SystemStats.writeRate); valueColor: Theme.ice
                            pulse: SystemStats.writeRate > 64 * 1024; live: panel.open
                        }
                    }
                }

                // --------------------------------------------------- network
                Section {
                    title: "Network"
                    glyph: "󰛳"
                    headline: Network.summary
                    headlineColor: Theme.muted
                    collapsed: store.collapsed.includes(title)
                    onToggled: panel.toggleSection(title)
                    visible: panel.s?.net != null
                    shown: panel.revealed
                    order: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Tile {
                            glyph: "󰇚"; caption: "Download"; value: SystemStats.rate(SystemStats.rxRate); valueColor: Theme.lightBlue
                            sub: panel.rxPeak > 0 ? "peak " + SystemStats.rate(panel.rxPeak) : ""
                            pulse: SystemStats.rxRate > 32 * 1024; live: panel.open
                        }
                        Tile {
                            glyph: "󰕒"; caption: "Upload"; value: SystemStats.rate(SystemStats.txRate); valueColor: Theme.ice
                            sub: panel.txPeak > 0 ? "peak " + SystemStats.rate(panel.txPeak) : ""
                            pulse: SystemStats.txRate > 32 * 1024; live: panel.open
                        }
                    }
                    Graph {
                        Layout.fillWidth: true
                        values: SystemStats.rxHistory
                        values2: SystemStats.txHistory
                        max: Math.max(64 * 1024, ...SystemStats.rxHistory, ...SystemStats.txHistory)
                        capacity: SystemStats.historyLength
                        glide: SystemStats.interval
                    }
                    KeyValue {
                        key: (panel.s?.net?.iface ?? "") + " · since boot"
                        value: panel.s?.net ? `↓ ${SystemStats.bytes(panel.s.net.rx)} · ↑ ${SystemStats.bytes(panel.s.net.tx)}` : ""
                    }
                }

                // --------------------------------------------------- battery
                Section {
                    id: batterySection
                    readonly property var dev: Power.display
                    readonly property real frac: dev?.percentage ?? 0
                    readonly property bool charging: (dev?.state ?? 0) === UPowerDeviceState.Charging
                    readonly property string lvl: UPower.onBattery ? (frac < 0.1 ? "critical" : frac < 0.2 ? "warn" : "normal") : "normal"
                    title: "Battery"
                    glyph: UPower.onBattery ? "󰁹" : "󰂄"
                    number: frac * 100
                    headlineColor: panel.tone(lvl)
                    collapsed: store.collapsed.includes(title)
                    onToggled: panel.toggleSection(title)
                    visible: dev?.isPresent ?? false
                    shown: panel.revealed
                    order: 7
                    GBar {
                        label: UPowerDeviceState.toString(batterySection.dev?.state ?? 0)
                        detail: ""
                        value: batterySection.frac
                        level: batterySection.lvl
                        shimmer: batterySection.charging
                        live: panel.open
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Tile {
                            caption: "Power draw"
                            value: Math.abs(batterySection.dev?.changeRate ?? 0).toFixed(1) + " W"
                        }
                        Tile {
                            readonly property real secs: UPower.onBattery ? (batterySection.dev?.timeToEmpty ?? 0) : (batterySection.dev?.timeToFull ?? 0)
                            visible: secs > 0   // nothing to show when full / unknown
                            caption: UPower.onBattery ? "Time left" : "Full in"
                            value: SystemStats.duration(secs)
                        }
                        Tile {
                            // health comes from the real battery (BAT0), not the display device
                            visible: Power.battery?.healthSupported ?? false
                            caption: "Health"
                            value: Math.round(Power.battery?.healthPercentage ?? 0) + "%"
                        }
                    }
                }

                // ------------------------------------------------- processes
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
                    glyph: "󰓅"
                    collapsed: store.collapsed.includes(title)
                    onToggled: panel.toggleSection(title)
                    visible: (panel.s?.procsCpu?.length ?? 0) > 0
                    shown: panel.revealed
                    order: 8
                    trailing: [
                        Segmented {
                            options: ["CPU", "Memory"]
                            current: procSection.byMemory ? 1 : 0
                            onPicked: i => procSection.byMemory = i === 1
                        }
                    ]

                    HoverHandler { id: procHover }

                    Repeater {
                        model: procSection.rows
                        delegate: MouseArea {
                            id: prow
                            required property var modelData
                            required property int index
                            readonly property bool confirming: procSection.confirmPid === modelData.pid
                            readonly property real usage: procSection.byMemory ? modelData.mem : modelData.cpu
                            readonly property string icon: panel.procIcon(modelData.name)
                            Layout.fillWidth: true
                            implicitHeight: 34
                            hoverEnabled: true
                            onExited: if (confirming) procSection.confirmPid = -1

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: prow.containsMouse ? Theme.overlay : Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.25)
                                border.width: prow.index === 0 ? 1 : 0
                                border.color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.30)
                                clip: true
                                // usage bar behind the row
                                Rectangle {
                                    width: parent.width * Math.min(1, prow.usage / 100)
                                    height: parent.height
                                    radius: 9
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.05) }
                                        GradientStop { position: 1; color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.24) }
                                    }
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                                }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 8
                                // app icon, or a letter badge
                                Item {
                                    implicitWidth: 20; implicitHeight: 20
                                    IconImage {
                                        id: picon
                                        anchors.fill: parent
                                        source: prow.icon
                                        implicitSize: 20
                                        visible: prow.icon !== "" && status === Image.Ready
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: !picon.visible
                                        radius: 6
                                        color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.16)
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: (prow.modelData.name || "?").charAt(0).toUpperCase()
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            font.weight: Font.Bold
                                            color: Theme.lightBlue
                                        }
                                    }
                                }
                                StyledText {
                                    text: prow.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSizeSmall + 1
                                    Layout.fillWidth: true
                                }
                                StyledText {
                                    visible: !prow.confirming
                                    text: prow.usage.toFixed(1) + "%"
                                    color: prow.index === 0 ? Theme.lightBlue : Theme.muted
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: prow.index === 0 ? Font.Bold : Font.Normal
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

                // ------------------------------------------------------ footer
                Row {
                    visible: panel.s !== null
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 2
                    Layout.bottomMargin: 4
                    spacing: 7
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        color: Theme.lightBlue
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `Live · every ${(SystemStats.interval / 1000).toFixed(1)} s · click a header to fold it`
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeSmall - 2
                    }
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
    // Soft round glow (radial gradient fading to transparent)
    component GlowBlob: Shape {
        id: blob
        property color tint: Theme.lightBlue
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"; strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: blob.width / 2; centerY: blob.height / 2; centerRadius: blob.width / 2
                focalX: blob.width / 2; focalY: blob.height / 2
                GradientStop { position: 0; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0.30) }
                GradientStop { position: 1; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0) }
            }
            PathRectangle { x: 0; y: 0; width: blob.width; height: blob.height }
        }
    }
    // Rounded bar with a blue -> ice gradient (solid tone for warnings);
    // `shimmer` sweeps a highlight across the fill (charging)
    component GradientLine: Rectangle {
        id: gl
        property real value
        property string level: "normal"
        property bool shimmer: false
        property bool live: true
        readonly property color end: level === "critical" ? Theme.critical : level === "warn" ? Theme.warn : Theme.ice
        readonly property color start: level === "critical" ? Theme.critical : level === "warn" ? Theme.warn : Theme.blue
        implicitHeight: 8
        radius: height / 2
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.5)
        Rectangle {
            id: fill
            height: parent.height
            width: Math.max(gl.value > 0 ? height : 0, parent.width * Math.min(1, gl.value))
            radius: height / 2
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: gl.start }
                GradientStop { position: 1; color: gl.end }
            }
            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }
            Rectangle {
                id: sheen
                visible: gl.shimmer
                width: 50; height: parent.height
                x: -50
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                }
                NumberAnimation on x {
                    running: gl.shimmer && gl.live
                    loops: Animation.Infinite
                    from: -50; to: fill.width + 50
                    duration: 1600
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
    // Pill with a glyph, for the hero
    component HeroChip: Rectangle {
        id: chip
        property string glyph
        property string label
        visible: label !== ""
        implicitWidth: crow.implicitWidth + 16
        implicitHeight: 24
        radius: 12
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.4)
        border.width: 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.08)
        Row {
            id: crow
            anchors.centerIn: parent
            spacing: 5
            Icon { text: chip.glyph; size: 12; color: Theme.lightBlue; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: chip.label; font.pixelSize: Theme.fontSizeSmall - 1; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    // A card that fades + rises in `order` x 45 ms after the panel opens.
    // With a title: header (icon chip · title · animated number or text ·
    // trailing items · chevron); clicking the header folds the body.
    // One component on purpose: an inline component based on another inline
    // component from the same file failed to load ("X is not a type").
    component Section: Rectangle {
        id: sec
        default property alias content: body.data
        property alias trailing: trail.data
        property bool shown: true
        property int order: 0
        property bool collapsed: false
        signal toggled()
        property string title
        property string glyph
        property string headline
        property real number: NaN       // animated headline number (instead of `headline`)
        property string unit: "%"
        property color headlineColor: Theme.lightBlue
        property real shownNumber: isNaN(number) ? 0 : number
        Behavior on shownNumber { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + 28
        radius: 12
        color: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.5)
        border.width: 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, secHover.hovered ? 0.16 : 0.06)
        Behavior on border.color { ColorAnimation { duration: 200 } }
        HoverHandler { id: secHover }
        opacity: shown ? 1 : 0
        transform: Translate {
            y: sec.shown ? 0 : 14
            Behavior on y { SequentialAnimation { PauseAnimation { duration: sec.shown ? sec.order * 45 : 0 } NumberAnimation { duration: 320; easing.type: Easing.OutQuint } } }
        }
        Behavior on opacity { SequentialAnimation { PauseAnimation { duration: sec.shown ? sec.order * 45 : 0 } NumberAnimation { duration: 280; easing.type: Easing.OutQuint } } }
        ColumnLayout {
            id: col
            x: 14; y: 14
            width: parent.width - 28
            spacing: 0
            MouseArea {
                visible: sec.title !== ""
                Layout.fillWidth: true
                implicitHeight: header.implicitHeight
                cursorShape: Qt.PointingHandCursor
                onClicked: sec.toggled()
                RowLayout {
                    id: header
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 10
                    Rectangle {
                        implicitWidth: 28; implicitHeight: 28
                        radius: 9
                        color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.15)
                        Icon { anchors.centerIn: parent; text: sec.glyph; size: 16; color: Theme.lightBlue }
                    }
                    StyledText { text: sec.title; font.weight: Font.Bold; color: Theme.ice }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        visible: !isNaN(sec.number) || sec.headline !== ""
                        text: !isNaN(sec.number) ? Math.round(sec.shownNumber) + sec.unit : sec.headline
                        color: sec.headlineColor
                        font.weight: Font.Bold
                        elide: Text.ElideLeft
                        Layout.maximumWidth: 200
                    }
                    Row { id: trail }
                    Icon {
                        text: "󰅀"   // chevron down; turns when folded
                        size: 14
                        color: Theme.muted
                        rotation: sec.collapsed ? -90 : 0
                        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                    }
                }
            }
            // body: folds to 0 height
            Item {
                Layout.fillWidth: true
                Layout.topMargin: sec.title !== "" && !sec.collapsed ? 12 : 0
                implicitHeight: sec.collapsed ? 0 : body.implicitHeight
                clip: true
                Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                Behavior on Layout.topMargin { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                opacity: sec.collapsed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 200 } }
                ColumnLayout {
                    id: body
                    width: parent.width
                    spacing: 10
                }
            }
        }
    }
    // Small stat tile: optional glyph (pulses while `pulse`), caption, value,
    // sub line and an optional thermometer bar
    component Tile: Rectangle {
        id: tile
        property string glyph
        property string caption
        property string value
        property string sub
        property color valueColor: Theme.text
        property real thermo: -1
        property bool pulse: false
        property bool live: true
        Layout.fillWidth: true
        Layout.preferredWidth: 1   // equal widths in a row
        implicitHeight: tcol.implicitHeight + 18
        radius: 10
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.35)
        clip: true
        ColumnLayout {
            id: tcol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 1
            RowLayout {
                spacing: 4
                Icon {
                    id: tglyph
                    visible: tile.glyph !== ""
                    text: tile.glyph
                    size: 12
                    color: tile.valueColor
                    SequentialAnimation on opacity {
                        running: tile.pulse && tile.live
                        loops: Animation.Infinite
                        onStopped: tglyph.opacity = 1
                        NumberAnimation { to: 0.3; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
                    }
                }
                StyledText { text: tile.caption; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall - 2 }
            }
            StyledText {
                text: tile.value
                color: tile.valueColor
                font.pixelSize: Theme.fontSize
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            StyledText {
                visible: tile.sub !== ""
                text: tile.sub
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall - 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            // thermometer: cool blue -> warn -> critical, marker at the value
            Item {
                visible: tile.thermo >= 0
                Layout.fillWidth: true
                Layout.topMargin: 3
                implicitHeight: 6
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.lightBlue }
                        GradientStop { position: 0.6; color: Theme.ice }
                        GradientStop { position: 0.75; color: Theme.warn }
                        GradientStop { position: 1; color: Theme.critical }
                    }
                    opacity: 0.45
                }
                Rectangle {
                    width: 4; height: 10; radius: 2
                    y: -2
                    x: Math.max(0, Math.min(parent.width - width, parent.width * tile.thermo - width / 2))
                    color: Theme.text
                    Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                }
            }
        }
    }
    // Ring + caption + detail, for the overview row
    component OverviewRing: ColumnLayout {
        id: ov
        property string caption
        property string detail
        property real value
        property string level: "normal"
        property bool live: true
        readonly property color c1: level === "critical" ? Theme.critical : level === "warn" ? Theme.warn : Theme.ice
        readonly property color c2: level === "critical" ? Theme.critical : level === "warn" ? Theme.warn : Theme.lightBlue
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 2
        RingGauge {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 80; implicitHeight: 80
            thickness: 7
            labelSize: Theme.fontSize
            ticks: true
            value: ov.value
            color: ov.c1
            color2: ov.c2
            alert: ov.level !== "normal"
            live: ov.live
        }
        // fillWidth on the texts: a column only stretches if a child does
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: ov.caption
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSizeSmall
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: ov.detail
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall - 2
            elide: Text.ElideRight
        }
    }
    // GPU card: name, big value, bar, sub line
    component GpuTile: Rectangle {
        id: gt
        property string name
        property string value
        property string sub
        property real fraction
        property bool asleep: false
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: gcol.implicitHeight + 20
        radius: 10
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.35)
        ColumnLayout {
            id: gcol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 10
            spacing: 4
            StyledText { text: gt.name; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall - 2 }
            StyledText {
                text: gt.value
                color: gt.asleep ? Theme.muted : Theme.text
                font.pixelSize: Theme.fontSize + 2
                font.weight: Font.Bold
            }
            GradientLine { Layout.fillWidth: true; value: gt.fraction; level: "normal" }
            StyledText { text: gt.sub; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall - 2; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }
    // Label · detail · percentage over a gradient bar
    component GBar: ColumnLayout {
        id: gb
        property string label
        property string detail
        property real value
        property string level: "normal"
        property bool shimmer: false
        property bool live: true
        property real shownValue: value
        Behavior on shownValue { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }
        Layout.fillWidth: true
        spacing: 5
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText { text: gb.label; font.pixelSize: Theme.fontSizeSmall }
            StyledText { text: gb.detail; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall - 1; elide: Text.ElideRight; Layout.fillWidth: true }
            StyledText {
                text: Math.round(Math.max(0, gb.shownValue) * 100) + "%"
                color: gb.level === "critical" ? Theme.critical : gb.level === "warn" ? Theme.warn : Theme.lightBlue
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
            }
        }
        GradientLine { Layout.fillWidth: true; value: gb.value; level: gb.level; shimmer: gb.shimmer; live: gb.live }
    }
    component KeyValue: RowLayout {
        property string key
        property string value
        property color valueColor: Theme.text
        Layout.fillWidth: true
        StyledText { text: parent.key; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall - 1 }
        Item { Layout.fillWidth: true }
        StyledText { text: parent.value; color: parent.valueColor; font.pixelSize: Theme.fontSizeSmall - 1; elide: Text.ElideLeft; Layout.maximumWidth: 260 }
    }
    // Placeholder card with a moving sheen, while the first numbers load
    component Skeleton: Rectangle {
        id: sk
        property bool live: true
        Layout.fillWidth: true
        radius: 12
        clip: true
        color: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.35)
        Rectangle {
            width: sk.width * 0.6; height: sk.height
            x: -width
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.07) }
                GradientStop { position: 1; color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0) }
            }
            NumberAnimation on x {
                running: sk.live && sk.visible
                loops: Animation.Infinite
                from: -sk.width * 0.6; to: sk.width
                duration: 1300
            }
        }
    }
    // Two-option switch with a sliding highlight
    component Segmented: Rectangle {
        id: seg
        property var options: []
        property int current: 0
        signal picked(int index)
        implicitWidth: segRow.implicitWidth + 6
        implicitHeight: 26
        radius: 13
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.45)
        Rectangle {
            // count: re-evaluate once the Repeater has made its items
            readonly property Item target: segRep.count > 0 ? segRep.itemAt(seg.current) : null
            x: 3 + (target?.x ?? 0)
            y: 3
            width: target?.width ?? 0
            height: parent.height - 6
            radius: height / 2
            color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.25)
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
        }
        Row {
            id: segRow
            x: 3
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                id: segRep
                model: seg.options
                delegate: MouseArea {
                    required property string modelData
                    required property int index
                    implicitWidth: segLabel.implicitWidth + 18
                    implicitHeight: 20
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(index)
                    StyledText {
                        id: segLabel
                        anchors.centerIn: parent
                        text: parent.modelData
                        font.pixelSize: Theme.fontSizeSmall - 1
                        font.weight: parent.index === seg.current ? Font.Bold : Font.Normal
                        color: parent.index === seg.current ? Theme.ice : Theme.muted
                    }
                }
            }
        }
    }
}

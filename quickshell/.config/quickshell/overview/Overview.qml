// Window overview, GNOME-style: 3-finger swipe up (down closes), ALT + A, or
// `qs ipc call overview toggle|open|close`.
//   top     "Type to search windows" + the 9 workspaces as mini-maps (where
//           each window sits, with its app icon; the one you're on has a dot)
//   middle  the selected workspace's windows as live thumbnails in a centred
//           grid; typing searches every workspace instead
//   click a window: focus it (switches workspace) · middle-click / ✕: close it
//   drag a window onto a workspace tile: move it there (you stay put)
//   click a tile: show its windows · double-click: go there
//   arrows + Enter: pick a window · Esc: clear the search, then close
// Live captures (ScreencopyView) run only while it's open.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PanelWindow {
    id: ov
    required property ShellScreen modelData
    screen: modelData

    property bool open: false
    property string query: ""
    property int selectedWs: 1
    property int sel: 0                   // keyboard-selected card
    property int dropWs: 0                // tile under a dragged window

    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeWs: monitor?.activeWorkspace?.id ?? 1
    readonly property var names: ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

    // Normal windows on workspaces 1-9 (no special workspaces, no layers)
    readonly property var wins: Hyprland.toplevels.values.filter(t => t.wayland && (t.workspace?.id ?? 0) >= 1 && (t.workspace?.id ?? 0) <= 9)
    function wsWins(id) { return wins.filter(t => t.workspace?.id === id) }
    function appId(t) { return t?.wayland?.appId || t?.lastIpcObject?.class || "" }
    readonly property var shown: {
        const q = query.trim().toLowerCase()
        if (!q) return wsWins(selectedWs)
        return wins.filter(t => (t.title || "").toLowerCase().includes(q) || appId(t).toLowerCase().includes(q))
    }

    // app icon, looked up once per app id (the fuzzy lookup isn't free)
    property var iconCache: ({})
    function iconFor(t) {
        const id = appId(t)
        if (!id) return ""
        if (id in iconCache) return iconCache[id]
        const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)
        const path = e && e.icon ? Quickshell.iconPath(e.icon, true) : Quickshell.iconPath(id.toLowerCase(), true)
        // last part of a reverse-DNS id (org.pwmt.zathura -> zathura), then a generic app icon
        iconCache[id] = path || Quickshell.iconPath(id.split(".").pop().toLowerCase(), true)
                        || Quickshell.iconPath("application-x-executable", true) || ""
        return iconCache[id]
    }

    function show() {
        Popups.close()
        Hyprland.refreshToplevels()       // window positions for the mini-maps
        search.text = ""
        selectedWs = activeWs
        sel = 0
        open = true
        hideAnim.stop()
        visible = true
        showAnim.restart()
        search.forceActiveFocus()
    }
    function close() {
        if (!open) return
        open = false
        Overlays.closed("overview", screen.name)
        showAnim.stop()
        hideAnim.restart()
    }
    function activate(t) { close(); t?.wayland?.activate() }
    function dispatch(lua) { Quickshell.execDetached(["hyprctl", "dispatch", lua]) }
    function moveTo(t, ws) {
        const a = String(t.address)
        const addr = a.startsWith("0x") ? a : "0x" + a
        dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:${addr}", follow = false })`)
        refreshTimer.restart()
    }
    function goTo(ws) { close(); dispatch(`hl.dsp.focus({ workspace = ${ws} })`) }
    Timer { id: refreshTimer; interval: 150; onTriggered: Hyprland.refreshToplevels() }

    Connections {
        target: Overlays
        function onOverviewChanged() { Overlays.overview === ov.screen.name ? ov.show() : ov.close() }
    }

    // --- grid: as many columns as gives the biggest thumbnails ---------------
    readonly property real gap: 28
    readonly property real labelH: 30
    readonly property real aspect: screen.width / Math.max(1, screen.height)
    readonly property var grid: {
        const n = shown.length, W = area.width, H = area.height
        if (n === 0 || W <= 0 || H <= 0) return { cols: 1, rows: 1, cw: 0, ch: 0 }
        let best = { cols: 1, rows: n, cw: 0, ch: 0 }
        for (let c = 1; c <= n; c++) {
            const r = Math.ceil(n / c)
            let cw = Math.min(W * 0.46, (W - (c - 1) * gap) / c)
            let ch = cw / aspect
            const maxCh = (H - (r - 1) * gap) / r - labelH
            if (ch > maxCh) { ch = maxCh; cw = ch * aspect }
            if (cw > best.cw) best = { cols: c, rows: r, cw: cw, ch: ch }
        }
        return best
    }
    function cardX(i) {
        const g = grid, row = Math.floor(i / g.cols)
        const inRow = row === g.rows - 1 ? shown.length - row * g.cols : g.cols
        const rowW = inRow * g.cw + (inRow - 1) * gap
        return (area.width - rowW) / 2 + (i - row * g.cols) * (g.cw + gap)
    }
    function cardY(i) {
        const g = grid, row = Math.floor(i / g.cols)
        const totalH = g.rows * (g.ch + labelH) + (g.rows - 1) * gap
        return (area.height - totalH) / 2 + row * (g.ch + labelH + gap)
    }

    // --- backdrop: Hyprland blurs it (quickshell layer rule) -----------------
    Rectangle {
        id: tint
        anchors.fill: parent
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.5)
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: ov.close() }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        scale: 0.96

        // search
        Rectangle {
            id: searchBox
            y: 34
            anchors.horizontalCenter: parent.horizontalCenter
            width: 440
            height: 42
            radius: 21
            color: Theme.glass
            border.width: 1
            border.color: search.activeFocus ? Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.5)
                                             : Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.14)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10
                Icon { text: "󰍉"; size: 17; color: Theme.muted }   // magnify
                Item {
                    Layout.fillWidth: true
                    implicitHeight: search.implicitHeight
                    TextInput {
                        id: search
                        anchors.left: parent.left
                        anchors.right: parent.right
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        selectionColor: Theme.blue
                        clip: true
                        onTextChanged: { ov.query = text; ov.sel = 0 }
                        Keys.onPressed: event => {
                            const n = ov.shown.length, cols = ov.grid.cols
                            if (event.key === Qt.Key_Escape) {
                                if (text !== "") text = ""; else ov.close()
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (n > 0) ov.activate(ov.shown[Math.min(ov.sel, n - 1)])
                            } else if (event.key === Qt.Key_Right) { if (n) ov.sel = (ov.sel + 1) % n }
                            else if (event.key === Qt.Key_Left) { if (n) ov.sel = (ov.sel - 1 + n) % n }
                            else if (event.key === Qt.Key_Down) { if (n) ov.sel = Math.min(n - 1, ov.sel + cols) }
                            else if (event.key === Qt.Key_Up) { if (n) ov.sel = Math.max(0, ov.sel - cols) }
                            else return
                            event.accepted = true
                        }
                    }
                    StyledText {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Type to search windows"
                        color: Theme.muted
                    }
                }
            }
        }

        // workspaces as mini-maps
        Row {
            id: strip
            anchors.top: searchBox.bottom
            anchors.topMargin: 22
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            visible: ov.query.trim() === ""

            Repeater {
                model: 9
                delegate: Column {
                    id: tile
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property var tileWins: ov.wsWins(wsId)
                    readonly property bool selected: ov.selectedWs === wsId
                    readonly property bool dropping: ov.dropWs === wsId
                    spacing: 5

                    Rectangle {
                        id: mini
                        width: 112
                        height: Math.round(112 / ov.aspect)
                        radius: 8
                        clip: true
                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.85)
                        border.width: tile.dropping || tile.selected ? 2 : 1
                        border.color: tile.dropping ? Theme.ice
                                    : tile.selected ? Theme.lightBlue
                                    : Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.14)
                        scale: tile.dropping ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }

                        // each window where it sits on the screen, with its icon
                        Repeater {
                            model: tile.tileWins
                            delegate: Rectangle {
                                required property var modelData
                                readonly property var o: modelData.lastIpcObject ?? ({})
                                readonly property real sx: mini.width / Math.max(1, ov.screen.width)
                                readonly property real sy: mini.height / Math.max(1, ov.screen.height)
                                x: ((o.at?.[0] ?? 0) - ov.screen.x) * sx
                                y: ((o.at?.[1] ?? 0) - ov.screen.y) * sy
                                width: Math.max(6, (o.size?.[0] ?? ov.screen.width) * sx)
                                height: Math.max(6, (o.size?.[1] ?? ov.screen.height) * sy)
                                radius: 3
                                color: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.95)
                                border.width: 1
                                border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.18)
                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: Math.min(16, parent.width - 4, parent.height - 4)
                                    source: ov.iconFor(parent.modelData)
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { search.text = ""; ov.selectedWs = tile.wsId; ov.sel = 0; search.forceActiveFocus() }
                            onDoubleClicked: ov.goTo(tile.wsId)
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5
                        Rectangle {   // you're on this one
                            visible: tile.wsId === ov.activeWs
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5; height: 5; radius: 2.5
                            color: Theme.lightBlue
                        }
                        StyledText {
                            text: ov.names[tile.index]
                            font.family: Theme.fontCjk
                            font.pixelSize: 14
                            font.weight: tile.selected ? Font.Bold : Font.Normal
                            color: tile.selected ? Theme.text : (tile.tileWins.length ? Theme.ice : Theme.muted)
                        }
                    }
                }
            }
        }

        // windows
        Item {
            id: area
            anchors.top: strip.visible ? strip.bottom : searchBox.bottom
            anchors.topMargin: 30
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 70
            anchors.rightMargin: 70
            anchors.bottomMargin: 50

            StyledText {
                visible: ov.shown.length === 0
                anchors.centerIn: parent
                text: ov.query.trim() ? "No windows match" : "No windows on this workspace"
                color: Theme.muted
                font.pixelSize: Theme.fontSize + 2
            }

            Repeater {
                model: ScriptModel { values: ov.shown }
                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool picked: ov.sel === index
                    readonly property string icon: ov.iconFor(modelData)
                    x: ov.cardX(index)
                    y: ov.cardY(index)
                    width: ov.grid.cw
                    height: ov.grid.ch + ov.labelH
                    z: drag.active ? 10 : 0
                    Behavior on x { enabled: !drag.active; NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    Behavior on y { enabled: !drag.active; NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                    transform: Translate {
                        x: drag.active ? drag.activeTranslation.x : 0
                        y: drag.active ? drag.activeTranslation.y : 0
                    }

                    // thumbnail box (the capture keeps the window's own shape)
                    Item {
                        id: box
                        width: card.width
                        height: ov.grid.ch
                        readonly property real srcW: shot.hasContent ? shot.sourceSize.width : 16
                        readonly property real srcH: shot.hasContent ? shot.sourceSize.height : 10
                        readonly property real fit: Math.min(width / Math.max(1, srcW), height / Math.max(1, srcH))
                        scale: hover.hovered && !drag.active ? 1.03 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }

                        ClippingRectangle {
                            id: frame
                            anchors.centerIn: parent
                            width: box.srcW * box.fit
                            height: box.srcH * box.fit
                            radius: 10
                            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.9)
                            ScreencopyView {
                                id: shot
                                width: frame.width
                                height: frame.height
                                captureSource: ov.visible ? card.modelData.wayland : null
                                live: ov.open
                                constraintSize: Qt.size(Math.ceil(ov.grid.cw), Math.ceil(ov.grid.ch))
                            }
                            IconImage {   // until the first frame arrives
                                visible: !shot.hasContent
                                x: (frame.width - 48) / 2; y: (frame.height - 48) / 2
                                implicitSize: 48
                                source: card.icon
                            }
                        }
                        // focus / hover outline
                        Rectangle {
                            anchors.fill: frame
                            anchors.margins: -3
                            radius: 13
                            color: "transparent"
                            border.width: 2
                            border.color: card.picked || hover.hovered ? Theme.lightBlue : "transparent"
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                        }
                        // close button on hover
                        Rectangle {
                            visible: hover.hovered && !drag.active
                            x: frame.x + frame.width - width / 2 - 6
                            y: frame.y - height / 2 + 6
                            width: 26; height: 26; radius: 13
                            color: closeArea.containsMouse ? Theme.critical : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.95)
                            border.width: 1
                            border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.25)
                            Icon { anchors.centerIn: parent; text: Glyphs.close; size: 13; color: Theme.text }
                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.modelData.wayland?.close()
                            }
                        }
                    }

                    // icon + title
                    Row {
                        anchors.top: box.bottom
                        anchors.topMargin: 8
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 7
                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 18
                            source: card.icon
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, card.width - 40)
                            text: card.modelData.title || ov.appId(card.modelData)
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeSmall
                            color: card.picked || hover.hovered ? Theme.text : Theme.ice
                        }
                        StyledText {   // which workspace, while searching
                            visible: ov.query.trim() !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "· " + ov.names[(card.modelData.workspace?.id ?? 1) - 1]
                            font.family: Theme.fontCjk
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.muted
                        }
                    }

                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: ov.activate(card.modelData)
                    }
                    TapHandler {
                        acceptedButtons: Qt.MiddleButton
                        onTapped: card.modelData.wayland?.close()
                    }
                    // drag onto a workspace tile to move the window there
                    DragHandler {
                        id: drag
                        target: null
                        onActiveTranslationChanged: {
                            const p = card.mapToItem(strip, card.width / 2 + activeTranslation.x, ov.grid.ch / 2 + activeTranslation.y)
                            let ws = 0
                            if (strip.visible) for (let i = 0; i < strip.children.length; i++) {
                                const c = strip.children[i]
                                if (c.wsId && p.x >= c.x && p.x <= c.x + c.width && p.y >= c.y && p.y <= c.y + c.height) ws = c.wsId
                            }
                            ov.dropWs = ws
                        }
                        onActiveChanged: if (!active) {
                            if (ov.dropWs && ov.dropWs !== (card.modelData.workspace?.id ?? 0)) ov.moveTo(card.modelData, ov.dropWs)
                            ov.dropWs = 0
                        }
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: tint; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuint }
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutQuint }
        NumberAnimation { target: content; property: "scale"; to: 1; duration: 280; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: tint; property: "opacity"; to: 0; duration: 170; easing.type: Easing.InOutCubic }
            NumberAnimation { target: content; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InOutCubic }
            NumberAnimation { target: content; property: "scale"; to: 0.96; duration: 170; easing.type: Easing.InOutCubic }
        }
        ScriptAction { script: ov.visible = false }
    }
}

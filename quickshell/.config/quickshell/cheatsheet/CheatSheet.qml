// Keybind cheat sheet (ALT + /): centered frosted card (~70% x 70%) over the
// blurred screen, binds grouped by category (from their "Category: Action"
// descriptions), live search as you type. Esc clears the search, then closes.
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
    id: sheet
    required property ShellScreen modelData
    screen: modelData

    property bool open: false
    property string query: ""

    WlrLayershell.namespace: "quickshell-cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false

    function show() {
        Popups.close()
        Keybinds.refresh()
        search.text = ""
        open = true
        hideAnim.stop()
        visible = true
        showAnim.restart()
        search.forceActiveFocus()
    }
    function close() {
        if (!open) return
        open = false
        Overlays.closed("cheatsheet", screen.name)
        showAnim.stop()
        hideAnim.restart()
    }
    // Opened/closed through services/Overlays.qml (keybind -> IPC -> the
    // focused monitor's overlay). A signal handler, not a binding: close()
    // writes back to Overlays.
    Connections {
        target: Overlays
        function onCheatsheetChanged() { Overlays.cheatsheet === sheet.screen.name ? sheet.show() : sheet.close() }
    }


    // Filter by action, keys or category (case-insensitive)
    readonly property var filtered: {
        const q = query.trim().toLowerCase()
        if (!q) return Keybinds.groups
        const out = []
        for (const g of Keybinds.groups) {
            const catHit = g.category.toLowerCase().includes(q)
            const items = g.items.filter(i => catHit || i.action.toLowerCase().includes(q)
                                              || i.keys.some(k => k.toLowerCase().includes(q)))
            if (items.length) out.push({ category: g.category, items: items })
        }
        return out
    }
    // Spread categories over 3 columns, always adding to the shortest one
    readonly property var columns: {
        const cols = [[], [], []], size = [0, 0, 0]
        for (const g of filtered) {
            const i = size.indexOf(Math.min(...size))
            cols[i].push(g)
            size[i] += g.items.length + 2
        }
        return cols
    }

    Rectangle {
        id: tint
        anchors.fill: parent
        color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.35)
        opacity: 0
        MouseArea { anchors.fill: parent; onClicked: sheet.close() }
    }

    Rectangle {
        id: card
        width: parent.width * 0.7
        height: parent.height * 0.7
        anchors.centerIn: parent
        radius: Theme.rounding + 4
        color: Theme.glass
        border.width: 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)
        opacity: 0
        scale: 0.97
        MouseArea { anchors.fill: parent }   // clicks inside don't close

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Icon { text: "󰌌"; size: 24; color: Theme.lightBlue }   // nf-md-keyboard
                StyledText { text: "Keybinds"; font.pixelSize: Theme.fontSize + 6; font.weight: Font.Bold }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 340
                    implicitHeight: 38
                    radius: 12
                    color: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.6)
                    border.width: 1
                    border.color: search.activeFocus ? Theme.lightBlue : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8
                        Icon { text: "󰍉"; size: 16; color: Theme.lightBlue }   // nf-md-magnify
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            clip: true
                            onTextChanged: sheet.query = text
                            Keys.onEscapePressed: text ? text = "" : sheet.close()
                            StyledText {
                                visible: !search.text
                                text: "Search keybinds…"
                                color: Theme.muted
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: cols.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                RowLayout {
                    id: cols
                    width: parent.width
                    spacing: 16

                    Repeater {
                        model: 3
                        delegate: ColumnLayout {
                            required property int index
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            spacing: 16

                            Repeater {
                                model: sheet.columns[index]
                                delegate: Card {
                                    id: groupCard
                                    required property var modelData
                                    Layout.fillWidth: true
                                    padding: 14
                                    ColumnLayout {
                                        width: parent.width
                                        spacing: 8
                                        StyledText {
                                            text: groupCard.modelData.category
                                            font.weight: Font.Bold
                                            color: Theme.ice
                                        }
                                        Repeater {
                                            model: groupCard.modelData.items
                                            delegate: RowLayout {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                spacing: 10
                                                StyledText {
                                                    text: modelData.action
                                                    font.pixelSize: Theme.fontSizeSmall + 1
                                                    wrapMode: Text.WordWrap
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 0
                                                }
                                                // Alternatives ("ALT + H" / "ALT + ←") as keycap groups
                                                Flow {
                                                    Layout.maximumWidth: 250   // fits "ALT SHIFT ← / ALT SHIFT H" on one line
                                                    Layout.preferredWidth: childrenRect.width
                                                    spacing: 4
                                                    layoutDirection: Qt.RightToLeft
                                                    Repeater {
                                                        // reversed: the flow runs right-to-left (right-aligned keycaps)
                                                        model: modelData.keys.slice().reverse()
                                                        delegate: Row {
                                                            id: combo
                                                            required property string modelData
                                                            required property int index
                                                            spacing: 3
                                                            // "/" between alternatives (list is reversed, see above)
                                                            StyledText {
                                                                visible: combo.index < combo.parent.children.length - 2
                                                                text: "/"
                                                                color: Theme.muted
                                                                font.pixelSize: Theme.fontSizeSmall
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                rightPadding: 2
                                                            }
                                                            Repeater {
                                                                model: modelData.split(" + ")
                                                                delegate: Rectangle {
                                                                    required property string modelData
                                                                    implicitWidth: capText.implicitWidth + 12
                                                                    implicitHeight: 22
                                                                    radius: 6
                                                                    color: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9)
                                                                    border.width: 1
                                                                    border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.15)
                                                                    StyledText {
                                                                        id: capText
                                                                        anchors.centerIn: parent
                                                                        text: modelData
                                                                        font.pixelSize: Theme.fontSizeSmall - 1
                                                                        color: Theme.lightBlue
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Keybinds.error !== "" ? Keybinds.error
                      : sheet.filtered.length === 0 ? "No keybinds match"
                      : "Esc closes · popups and menus also close with Esc · 3-finger swipe switches workspace"
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: tint; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutQuint }
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuint }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 240; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: tint; property: "opacity"; to: 0; duration: 160; easing.type: Easing.InOutCubic }
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 150; easing.type: Easing.InOutCubic }
            NumberAnimation { target: card; property: "scale"; to: 0.97; duration: 150 }
        }
        ScriptAction { script: sheet.visible = false }
    }
}

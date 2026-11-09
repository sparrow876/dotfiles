// Palette-themed replacement for a tray app's right-click menu.
// Reads the app's menu over D-Bus (QsMenuOpener) and draws it ourselves.
// Submenus open in place with a "back" row. Closes on Esc, outside click,
// clicking the same icon again, or after choosing an entry.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components

PopupWindow {
    id: popup
    required property var barWindow
    property var trayItem: null
    property var anchorItem: null
    property var menuStack: []          // parent menus, for the back button

    function toggle(item, slot) {
        if (visible && trayItem === item) { close(); return }
        trayItem = item
        anchorItem = slot
        menuStack = []
        opener.menu = item.menu
        anchor.item = slot
        visible = true
    }
    function close() {
        visible = false
        trayItem = null
        opener.menu = null
    }

    anchor.window: barWindow
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 14
    implicitWidth: 270
    implicitHeight: Math.min(column.implicitHeight + 12, 520)
    color: "transparent"
    visible: false

    QsMenuOpener { id: opener }

    // Close when clicking anywhere outside the menu
    HyprlandFocusGrab {
        active: popup.visible
        windows: [popup]
        onCleared: popup.close()
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.95)
        border.width: 1
        border.color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)
        focus: true
        Keys.onEscapePressed: popup.close()

        Flickable {
            anchors.fill: parent
            anchors.margins: 6
            contentHeight: column.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: column
                width: parent.width
                spacing: 0

                // Back row inside a submenu
                MenuRow {
                    visible: popup.menuStack.length > 0
                    label: "Back"
                    glyph: "󰁍"   // nf-md-arrow_left
                    onActivated: {
                        const stack = popup.menuStack.slice()
                        opener.menu = stack.pop()
                        popup.menuStack = stack
                    }
                }

                Repeater {
                    model: opener.children

                    delegate: Loader {
                        id: entryLoader
                        required property var modelData
                        Layout.fillWidth: true
                        sourceComponent: modelData.isSeparator ? separator : row

                        Component {
                            id: separator
                            Item {
                                implicitHeight: 9
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 16
                                    height: 1
                                    color: Theme.overlay
                                }
                            }
                        }
                        Component {
                            id: row
                            MenuRow {
                                entry: entryLoader.modelData
                                label: entryLoader.modelData.text.replace(/_(?!_)/g, "")  // strip mnemonics
                                iconSource: entryLoader.modelData.icon
                                enabled: entryLoader.modelData.enabled
                                checkable: entryLoader.modelData.buttonType !== QsMenuButtonType.None
                                checked: entryLoader.modelData.checkState === Qt.Checked
                                radio: entryLoader.modelData.buttonType === QsMenuButtonType.RadioButton
                                hasChildren: entryLoader.modelData.hasChildren
                                onActivated: {
                                    const e = entryLoader.modelData
                                    if (e.hasChildren) {
                                        popup.menuStack = popup.menuStack.concat([opener.menu])
                                        opener.menu = e
                                    } else {
                                        e.triggered()
                                        popup.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // One clickable row of the menu
    component MenuRow: MouseArea {
        id: r
        property var entry: null
        property string label: ""
        property string glyph: ""
        property string iconSource: ""
        property bool checkable: false
        property bool checked: false
        property bool radio: false
        property bool hasChildren: false
        signal activated()

        Layout.fillWidth: true
        implicitHeight: 34
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (enabled) activated()

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: r.containsMouse && r.enabled ? Theme.overlay : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Icon {
                visible: r.checkable
                text: r.radio ? (r.checked ? "󰐾" : "󰄰") : (r.checked ? "󰄲" : "󰄱")
                color: r.checked ? Theme.lightBlue : Theme.muted
                size: 15
            }
            Icon {
                visible: r.glyph !== ""
                text: r.glyph
                color: Theme.muted
                size: 15
            }
            IconImage {
                visible: r.iconSource !== "" && !r.checkable
                source: r.iconSource
                implicitSize: 16
            }
            StyledText {
                Layout.fillWidth: true
                text: r.label
                elide: Text.ElideRight
                color: r.enabled ? Theme.text : Theme.muted
            }
            Icon {
                visible: r.hasChildren
                text: "󰅂"   // nf-md-chevron_right
                color: Theme.muted
                size: 14
            }
        }
    }
}

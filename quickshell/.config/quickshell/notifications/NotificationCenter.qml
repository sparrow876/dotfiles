// Notification center: dropdown under the bell (or ALT + N), ~380px wide and
// ~60% of the screen tall. Do Not Disturb switch at the top, history grouped by
// app (newest first) with "clear" per notification, per app and for everything.
// Clicking a notification runs its default action (e.g. focuses the app).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.components
import qs.popups
import qs.services

PopupFrame {
    id: center
    name: "notifications"
    contentWidth: 380

    property date now: new Date()
    onOpened: { now = new Date(); Notifications.markRead() }
    // Notifications that arrived while it was open were seen: no bell dot after closing
    onShouldShowChanged: if (!shouldShow) Notifications.markRead()
    // Refresh "5 min ago" labels only while open
    Timer { running: center.visible; interval: 30000; repeat: true; onTriggered: center.now = new Date() }

    // --- Header: title, DND, clear all ----------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        StyledText { text: "Notifications"; font.weight: Font.Bold; Layout.fillWidth: true }
        TextButton {
            visible: Notifications.history.length > 0
            label: "Clear all"
            onClicked: Notifications.clearAll()
        }
    }

    Card {
        Layout.fillWidth: true
        padding: 10
        RowLayout {
            width: parent.width
            spacing: 10
            Icon {
                text: Notifications.dndActive ? Glyphs.bellOff : Glyphs.bell
                color: Notifications.dndActive ? Theme.warn : Theme.lightBlue
                size: 18
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 0
                StyledText { text: "Do not disturb" }
                StyledText {
                    text: Notifications.gameFullscreen && !Notifications.dnd
                          ? "On while a game is fullscreen"
                          : Notifications.dnd ? "Popups hidden (critical still shown)" : "Popups shown"
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Toggle {
                checked: Notifications.dnd
                onToggled: Notifications.dnd = !Notifications.dnd
            }
        }
    }

    // --- History --------------------------------------------------------------
    Flickable {
        id: scroller
        Layout.fillWidth: true
        // ~60% of the screen in total, minus the header above
        Layout.preferredHeight: Math.round((center.barWindow.screen?.height ?? 1080) * 0.6) - 130
        contentHeight: groupsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: groupsColumn
            width: scroller.width
            spacing: 14

            // Empty state
            ColumnLayout {
                visible: Notifications.history.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 60
                spacing: 8
                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰂜"   // nf-md-bell_outline
                    size: 40
                    color: Theme.overlay
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No notifications"
                    color: Theme.muted
                }
            }

            Repeater {
                model: ScriptModel { values: Notifications.groups; objectProp: "app" }
                delegate: ColumnLayout {
                    id: group
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6

                    // App header: icon, name, count, clear app
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        IconImage {
                            implicitSize: 18
                            source: Notifications.iconSource(group.modelData.items[0])
                            visible: status === Image.Ready
                        }
                        StyledText {
                            text: group.modelData.app
                            font.weight: Font.Bold
                            font.pixelSize: Theme.fontSizeSmall + 1
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: group.modelData.items.length
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        IconButton {
                            glyph: Glyphs.close
                            size: 13
                            color: Theme.muted
                            tooltip: `Clear ${group.modelData.app}`
                            onClicked: Notifications.clearApp(group.modelData.app)
                        }
                    }

                    Repeater {
                        model: ScriptModel { values: group.modelData.items }
                        delegate: MouseArea {
                            id: item
                            required property var modelData
                            readonly property var n: modelData
                            readonly property bool critical: n.urgency === NotificationUrgency.Critical
                            Layout.fillWidth: true
                            implicitHeight: content.implicitHeight + 20
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { Notifications.activate(n); Popups.close() }

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: item.containsMouse ? Theme.overlay : Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.45)
                                border.width: item.critical ? 1 : 0
                                border.color: Theme.critical
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            RowLayout {
                                id: content
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10
                                spacing: 10

                                ClippingRectangle {
                                    id: thumb
                                    readonly property string src: Notifications.imageSource(item.n)
                                    visible: src !== "" && pic.status === Image.Ready
                                    Layout.alignment: Qt.AlignTop
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    radius: 8
                                    color: "transparent"
                                    Image { id: pic; anchors.fill: parent; source: thumb.src; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 0
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText {
                                            text: item.n.summary
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        StyledText {
                                            text: Notifications.timeAgo(item.n, center.now)
                                            color: Theme.muted
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                        IconButton {
                                            glyph: Glyphs.close
                                            size: 12
                                            color: Theme.muted
                                            tooltip: "Clear"
                                            onClicked: Notifications.dismiss(item.n)
                                        }
                                    }
                                    StyledText {
                                        visible: text !== ""
                                        text: Notifications.bodyText(item.n)
                                        textFormat: Text.StyledText
                                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.8)
                                        font.pixelSize: Theme.fontSizeSmall
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                        linkColor: Theme.lightBlue
                                        onLinkActivated: link => Qt.openUrlExternally(link)
                                        Layout.fillWidth: true
                                    }
                                    // Action buttons (e.g. Edit / Open / Open folder on a
                                    // screenshot), still usable after the popup is gone
                                    RowLayout {
                                        visible: centerActions.count > 0
                                        Layout.fillWidth: true
                                        Layout.topMargin: 4
                                        spacing: 6
                                        Repeater {
                                            id: centerActions
                                            model: item.n.actions.filter(a => a.identifier !== "default" && a.text !== "")
                                            delegate: TextButton {
                                                required property var modelData
                                                label: modelData.text
                                                Layout.fillWidth: true
                                                onClicked: { modelData.invoke(); Popups.close() }
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

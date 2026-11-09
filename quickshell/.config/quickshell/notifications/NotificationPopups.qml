// Notification popups: frosted cards in the top-right corner under the bar.
// Icon/image, app name, title, body, action buttons. Max 3 stacked.
// Hover pauses the 5 s timer, click runs the app's default action (e.g. focuses
// Teams/Discord), ✕ or swiping right dismisses. Critical ones have a red edge
// and stay until dismissed.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PanelWindow {
    id: win
    required property ShellScreen modelData
    screen: modelData
    // Only on the focused monitor
    visible: Notifications.popups.length > 0 && modelData.name === Overlays.focusedScreen()

    WlrLayershell.namespace: "quickshell-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 8 + 44 + 10; right: 12 }
    implicitWidth: 380
    implicitHeight: Math.max(1, column.implicitHeight)
    color: "transparent"

    Column {
        id: column
        width: parent.width
        spacing: 10

        Repeater {
            // ScriptModel keeps existing cards when the list changes (no restarted
            // animations), only adding/removing what changed.
            model: ScriptModel { values: Notifications.popups.slice(0, Notifications.maxPopups) }
            delegate: Card {}
        }
    }

    component Card: Item {
        id: card
        required property var modelData
        readonly property var n: modelData
        readonly property bool critical: n.urgency === NotificationUrgency.Critical
        readonly property string imageSource: Notifications.imageSource(n)
        readonly property string iconSource: Notifications.iconSource(n)

        width: column.width
        height: body.implicitHeight + 28
        opacity: 0
        x: 40

        Component.onCompleted: enter.start()
        ParallelAnimation {
            id: enter
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutQuint }
            NumberAnimation { target: card; property: "x"; to: 0; duration: 260; easing.type: Easing.OutQuint }
        }

        // Auto-hide is handled by the service; hovering (or dragging) pauses it.
        // HoverHandler on the card itself stays "hovered" over its buttons too
        // (the MouseArea below loses hover to the ✕ / action buttons on top of it).
        HoverHandler { id: cardHover }
        readonly property bool paused: cardHover.hovered || hover.drag.active
        onPausedChanged: Notifications.setHovered(n, paused)
        Component.onDestruction: if (paused) Notifications.setHovered(n, false)

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            drag.target: frame
            drag.axis: Drag.XAxis
            drag.minimumX: 0
            drag.maximumX: card.width
            onReleased: {
                if (frame.x > card.width * 0.35) Notifications.hidePopup(card.n)   // swiped away
                else frame.x = 0
            }
            onClicked: if (frame.x < 4) Notifications.activate(card.n)
        }

        Rectangle {
            id: frame
            width: parent.width
            height: parent.height
            radius: Theme.rounding
            color: Theme.glass
            border.width: 1
            border.color: card.critical ? Theme.critical : Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.12)
            opacity: 1 - Math.min(0.8, x / card.width)
            Behavior on x { enabled: !hover.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }

            ColumnLayout {
                id: body
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // App icon, or the notification's own image if it has one
                    Item {
                        Layout.alignment: Qt.AlignTop
                        implicitWidth: 40
                        implicitHeight: 40
                        ClippingRectangle {
                            anchors.fill: parent
                            radius: 10
                            color: "transparent"
                            visible: card.imageSource !== "" && picture.status === Image.Ready
                            Image {
                                id: picture
                                anchors.fill: parent
                                source: card.imageSource
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                        IconImage {
                            id: appIcon
                            visible: !(card.imageSource !== "" && picture.status === Image.Ready) && status === Image.Ready
                            anchors.centerIn: parent
                            implicitSize: 34
                            source: card.iconSource
                        }
                        // Nothing loadable: a bell glyph instead of a broken image
                        Icon {
                            visible: !(card.imageSource !== "" && picture.status === Image.Ready) && appIcon.status !== Image.Ready
                            anchors.centerIn: parent
                            text: "󰂚"   // nf-md-bell
                            size: 26
                            color: card.critical ? Theme.critical : Theme.lightBlue
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                text: card.n.appName || "Notification"
                                color: Theme.muted
                                font.pixelSize: Theme.fontSizeSmall
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            IconButton {
                                glyph: Glyphs.close
                                size: 14
                                color: Theme.muted
                                tooltip: "Dismiss"
                                onClicked: Notifications.dismiss(card.n)
                            }
                        }
                        StyledText {
                            text: card.n.summary
                            font.weight: Font.Bold
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            visible: text !== ""
                            text: card.n.body
                            textFormat: Text.StyledText
                            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.85)
                            font.pixelSize: Theme.fontSizeSmall + 1
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            linkColor: Theme.lightBlue
                            onLinkActivated: link => Qt.openUrlExternally(link)
                            Layout.fillWidth: true
                        }
                    }
                }

                // Action buttons (except the hidden "default" one, which is the click)
                RowLayout {
                    visible: actions.count > 0
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        id: actions
                        model: card.n.actions.filter(a => a.identifier !== "default" && a.text !== "")
                        delegate: TextButton {
                            required property var modelData
                            label: modelData.text
                            Layout.fillWidth: true
                            onClicked: { modelData.invoke(); Notifications.hidePopup(card.n) }
                        }
                    }
                }
            }
        }
    }
}

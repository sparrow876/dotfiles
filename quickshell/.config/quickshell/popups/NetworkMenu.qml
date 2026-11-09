// Wi-Fi menu: on/off, rescan, current connection (SSID, signal, IP, Disconnect),
// ethernet status, networks sorted by signal (lock = secured, check = saved).
// Saved/open network -> click connects. New secured network -> inline password
// field (show/hide) with a clear error if it fails. "⋯" on saved networks -> Forget.
// "Advanced…" opens nm-connection-editor. Scans only while open.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking as N
import qs
import qs.components
import qs.services

PopupFrame {
    id: menu
    name: "network"
    contentWidth: 380

    property var expanded: null        // network showing the password field
    property var optionsFor: null      // network showing "Forget"

    onOpened: {
        Network.refreshIp()
        Network.setScanner(true)
    }
    onShouldShowChanged: if (!shouldShow) {
        Network.setScanner(false)
        expanded = null
        optionsFor = null
    }

    // --- Header ---------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        StyledText { text: "Wi-Fi"; font.weight: Font.Bold; Layout.fillWidth: true }
        Spinner { visible: Network.scanning; size: 16 }
        IconButton {
            visible: !Network.scanning && Network.wifiEnabled
            glyph: Glyphs.refresh
            size: 16
            tooltip: "Scan again"
            onClicked: Network.rescan()
        }
        Toggle {
            checked: Network.wifiEnabled
            onToggled: Network.setWifiEnabled(!checked)
        }
    }

    StyledText {
        visible: Network.wifiBlocked
        text: "Wi-Fi is blocked by the hardware switch / airplane mode."
        color: Theme.warn
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    // --- Current connection ---------------------------------------------------
    Card {
        visible: Network.active !== null
        Layout.fillWidth: true
        RowLayout {
            width: parent.width
            spacing: 12
            Icon {
                text: Glyphs.wifiLevels[Network.levelOf(Network.active)]
                color: Theme.lightBlue
                size: 22
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0      // take the leftover space, never push the button out
                spacing: 2
                StyledText {
                    text: Network.active?.name ?? ""
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                StyledText {
                    text: `Signal ${Math.round((Network.active?.signalStrength ?? 0) * 100)}%` + (Network.ip ? ` · ${Network.ip}` : "")
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            TextButton {
                label: "Disconnect"
                onClicked: Network.active?.disconnect()
            }
        }
    }

    // --- Ethernet -------------------------------------------------------------
    RowLayout {
        visible: Network.wired !== null
        spacing: 10
        Icon { text: Glyphs.ethernet; color: Network.wiredConnected ? Theme.lightBlue : Theme.muted; size: 18 }
        StyledText {
            text: Network.wiredConnected ? "Ethernet connected" : "Ethernet unplugged"
            color: Network.wiredConnected ? Theme.text : Theme.muted
        }
    }

    // --- Other networks -------------------------------------------------------
    StyledText {
        visible: Network.wifiEnabled
        text: "Networks"
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
    }

    ListView {
        id: list
        visible: Network.wifiEnabled
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 320)
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: Network.networks.filter(n => !n.connected)

        delegate: ColumnLayout {
            id: entry
            required property var modelData
            readonly property var net: modelData
            readonly property bool secured: Network.isSecured(net)
            readonly property bool busy: net.state === N.ConnectionState.Connecting
            property string error: ""
            width: list.width
            spacing: 4

            Connections {
                target: entry.net
                function onConnectionFailed(reason) {
                    entry.error = Network.failMessage(reason)
                    if (!entry.net.known) menu.expanded = entry.net
                }
                function onConnectedChanged() {
                    if (entry.net.connected) { entry.error = ""; menu.expanded = null }
                }
            }

            MouseArea {
                Layout.fillWidth: true
                implicitHeight: 38
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    entry.error = ""
                    menu.optionsFor = null
                    if (entry.net.known || !entry.secured) entry.net.connect()
                    else menu.expanded = menu.expanded === entry.net ? null : entry.net
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: parent.containsMouse ? Theme.overlay : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 4
                    spacing: 10
                    Icon { text: Glyphs.wifiLevels[Network.levelOf(entry.net)]; size: 18; color: Theme.text }
                    StyledText { text: entry.net.name; elide: Text.ElideRight; Layout.fillWidth: true }
                    Icon { visible: entry.net.known; text: Glyphs.check; size: 15; color: Theme.lightBlue }
                    Icon { visible: entry.secured; text: Glyphs.lock; size: 15; color: Theme.muted }
                    Spinner { visible: entry.busy; size: 15 }
                    IconButton {
                        visible: entry.net.known && !entry.busy
                        glyph: Glyphs.dots
                        size: 15
                        tooltip: "Options"
                        onClicked: menu.optionsFor = menu.optionsFor === entry.net ? null : entry.net
                    }
                }
            }

            // "Forget" for saved networks
            RowLayout {
                visible: menu.optionsFor === entry.net
                Layout.leftMargin: 38
                TextButton {
                    label: "Forget this network"
                    danger: true
                    onClicked: { entry.net.forget(); menu.optionsFor = null }
                }
            }

            // Password for a new secured network
            RowLayout {
                visible: menu.expanded === entry.net
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                spacing: 6
                onVisibleChanged: if (visible) password.forceActiveFocus()

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: 10
                    color: Theme.base
                    border.width: 1
                    border.color: password.activeFocus ? Theme.lightBlue : Theme.overlay

                    TextInput {
                        id: password
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 34
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        echoMode: reveal.shown ? TextInput.Normal : TextInput.Password
                        clip: true
                        onAccepted: connectButton.clicked(null)
                        Keys.onEscapePressed: menu.expanded = null
                        StyledText {
                            visible: !password.text && !password.activeFocus
                            text: "Password"
                            color: Theme.muted
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    IconButton {
                        id: reveal
                        property bool shown: false
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: shown ? Glyphs.eyeOff : Glyphs.eye
                        size: 15
                        color: Theme.muted
                        tooltip: shown ? "Hide password" : "Show password"
                        onClicked: shown = !shown
                    }
                }
                TextButton {
                    id: connectButton
                    label: "Connect"
                    primary: true
                    enabled: password.text.length >= 8
                    onClicked: {
                        entry.error = ""
                        entry.net.connectWithPsk(password.text)
                        password.text = ""   // don't keep it around
                    }
                }
            }

            StyledText {
                visible: entry.error !== ""
                text: entry.error
                color: Theme.critical
                font.pixelSize: Theme.fontSizeSmall
                Layout.leftMargin: 38
            }
        }
    }

    StyledText {
        visible: Network.wifiEnabled && list.count === 0
        text: Network.scanning ? "Scanning…" : "No other networks found"
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
    }

    // --- Footer ---------------------------------------------------------------
    TextButton {
        label: "Advanced…"
        Layout.alignment: Qt.AlignRight
        onClicked: {
            Quickshell.execDetached(["nm-connection-editor"])
            Popups.close()
        }
    }
}

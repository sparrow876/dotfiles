// Bluetooth menu: power toggle, scan (spinner), paired devices (click to
// connect/disconnect, battery %, "⋯" -> Forget), available devices (click to pair,
// then it's trusted and connected). "Advanced…" opens blueman-manager.
// Pairing that needs a PIN/number confirmation can't be answered here (no
// pairing agent in Quickshell); the menu says so and points to Advanced….
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth as B
import qs
import qs.components
import qs.services

PopupFrame {
    id: menu
    name: "bluetooth"
    contentWidth: 360

    property var optionsFor: null
    property var pairingDevice: null
    property string pairError: ""

    onShouldShowChanged: if (!shouldShow) {
        Bluetooth.setDiscovering(false)
        optionsFor = null
        pairError = ""
    }

    // After a successful pair: trust it (reconnects automatically later) and connect
    Connections {
        target: menu.pairingDevice
        function onPairedChanged() {
            const d = menu.pairingDevice
            if (d && d.paired) {
                d.trusted = true
                d.connect()
                menu.pairingDevice = null
            }
        }
        function onPairingChanged() {
            const d = menu.pairingDevice
            if (d && !d.pairing && !d.paired) {
                menu.pairError = `Couldn't pair with ${d.name}. If it asks for a PIN or a code confirmation, use Advanced….`
                menu.pairingDevice = null
            }
        }
    }

    // --- Header ---------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        StyledText { text: "Bluetooth"; font.weight: Font.Bold; Layout.fillWidth: true }
        Spinner { visible: Bluetooth.discovering; size: 16 }
        IconButton {
            visible: Bluetooth.enabled && !Bluetooth.discovering
            glyph: Glyphs.refresh
            size: 16
            tooltip: "Scan for devices"
            onClicked: Bluetooth.setDiscovering(true)
        }
        Toggle {
            checked: Bluetooth.enabled
            onToggled: Bluetooth.setEnabled(!checked)
        }
    }

    StyledText {
        visible: !Bluetooth.available
        text: "No Bluetooth adapter found."
        color: Theme.muted
    }

    // --- Paired ---------------------------------------------------------------
    StyledText {
        visible: Bluetooth.enabled && Bluetooth.paired.length > 0
        text: "Paired devices"
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
    }
    Repeater {
        model: Bluetooth.enabled ? Bluetooth.paired : []
        delegate: ColumnLayout {
            id: row
            required property var modelData
            readonly property var dev: modelData
            readonly property bool busy: dev.state === B.BluetoothDeviceState.Connecting
                                      || dev.state === B.BluetoothDeviceState.Disconnecting
            Layout.fillWidth: true
            spacing: 4

            DeviceRow {
                Layout.fillWidth: true
                device: row.dev
                subtitle: row.busy ? (row.dev.connected ? "Disconnecting…" : "Connecting…")
                        : row.dev.connected ? "Connected" + (row.dev.batteryAvailable ? ` · battery ${Math.round(row.dev.battery * 100)}%` : "")
                        : "Not connected"
                highlighted: row.dev.connected
                busy: row.busy
                showOptions: true
                onActivated: row.dev.connected ? row.dev.disconnect() : row.dev.connect()
                onOptions: menu.optionsFor = menu.optionsFor === row.dev ? null : row.dev
            }
            TextButton {
                visible: menu.optionsFor === row.dev
                Layout.leftMargin: 42
                label: "Forget this device"
                danger: true
                onClicked: { row.dev.forget(); menu.optionsFor = null }
            }
        }
    }

    StyledText {
        visible: Bluetooth.enabled && Bluetooth.paired.length === 0 && !Bluetooth.discovering && Bluetooth.unpaired.length === 0
        text: "No paired devices yet. Press 󰑐 to look for nearby devices."
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    // --- Available ------------------------------------------------------------
    StyledText {
        visible: Bluetooth.enabled && (Bluetooth.discovering || Bluetooth.unpaired.length > 0)
        text: "Available devices"
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
    }
    Repeater {
        model: Bluetooth.enabled ? Bluetooth.unpaired : []
        delegate: DeviceRow {
            required property var modelData
            Layout.fillWidth: true
            device: modelData
            subtitle: modelData.pairing ? "Pairing…" : "Click to pair"
            busy: modelData.pairing
            onActivated: {
                menu.pairError = ""
                menu.pairingDevice = modelData
                modelData.pair()
            }
        }
    }
    StyledText {
        visible: Bluetooth.enabled && Bluetooth.discovering && Bluetooth.unpaired.length === 0
        text: "Looking for devices… make sure yours is in pairing mode."
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    StyledText {
        visible: menu.pairError !== ""
        text: menu.pairError
        color: Theme.critical
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    // --- Footer ---------------------------------------------------------------
    TextButton {
        label: "Advanced…"
        Layout.alignment: Qt.AlignRight
        onClicked: {
            Quickshell.execDetached(["blueman-manager"])
            Popups.close()
        }
    }

    component DeviceRow: MouseArea {
        id: r
        property var device
        property string subtitle: ""
        property bool highlighted: false
        property bool busy: false
        property bool showOptions: false
        signal activated()
        signal options()

        implicitHeight: 46
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!busy) activated()

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: r.containsMouse ? Theme.overlay : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 4
            spacing: 12
            Icon {
                text: Bluetooth.deviceGlyph(r.device)
                color: r.highlighted ? Theme.lightBlue : Theme.text
                size: 20
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText { text: r.device.name; elide: Text.ElideRight; Layout.fillWidth: true }
                StyledText { text: r.subtitle; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall }
            }
            Spinner { visible: r.busy; size: 15 }
            IconButton {
                visible: r.showOptions && !r.busy
                glyph: Glyphs.dots
                size: 15
                tooltip: "Options"
                onClicked: r.options()
            }
        }
    }
}

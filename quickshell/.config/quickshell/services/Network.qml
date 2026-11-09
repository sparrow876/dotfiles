// Network state from NetworkManager (Quickshell.Networking, event-driven: no
// polling). Used by bar/NetworkIcon.qml and popups/NetworkMenu.qml.
// Passwords go straight to NetworkManager; nothing here stores or logs them.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking as N
import qs.components

Singleton {
    id: root

    readonly property var devices: N.Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === N.DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === N.DeviceType.Wired) ?? null
    readonly property bool wifiEnabled: N.Networking.wifiEnabled
    readonly property bool wifiBlocked: !N.Networking.wifiHardwareEnabled

    // Visible Wi-Fi networks, strongest first
    readonly property var networks: wifi ? wifi.networks.values.slice()
                                               .filter(n => n.name.length > 0)
                                               .sort((a, b) => b.signalStrength - a.signalStrength) : []
    readonly property var active: networks.find(n => n.connected) ?? null
    readonly property bool connecting: networks.some(n => n.state === N.ConnectionState.Connecting)
    readonly property bool wiredConnected: wired?.connected ?? false

    function levelOf(network) { return Math.max(0, Math.min(3, Math.floor((network?.signalStrength ?? 0) * 4))) }
    function isSecured(network) { return network.security !== N.WifiSecurityType.Open }

    // Bar icon: ethernet, off, connecting (animated), signal level, or disconnected
    property int pulse: 0
    Timer {
        running: root.connecting
        interval: 350
        repeat: true
        onTriggered: root.pulse = (root.pulse + 1) % 4
    }
    readonly property string glyph: wiredConnected && !active ? Glyphs.ethernet
                                  : !wifiEnabled ? Glyphs.wifiOff
                                  : connecting ? Glyphs.wifiLevels[pulse]
                                  : active ? Glyphs.wifiLevels[levelOf(active)]
                                  : Glyphs.wifiNone
    readonly property string summary: active ? `${active.name} · ${Math.round(active.signalStrength * 100)}%`
                                    : wiredConnected ? "Ethernet connected"
                                    : !wifiEnabled ? "Wi-Fi off"
                                    : connecting ? "Connecting…" : "Not connected"

    function setWifiEnabled(on) { N.Networking.wifiEnabled = on }

    // Scanning: only while the menu is open (saves power)
    property bool scanning: false
    function setScanner(on) { if (wifi) wifi.scannerEnabled = on }
    function rescan() {
        if (!wifi) return
        wifi.scannerEnabled = false
        wifi.scannerEnabled = true
        scanning = true
        scanTimer.restart()
    }
    Timer { id: scanTimer; interval: 4000; onTriggered: root.scanning = false }

    // IPv4 address of the active connection (read once when the menu opens)
    property string ip: ""
    function refreshIp() { ipProc.running = true }
    Process {
        id: ipProc
        command: ["ip", "-j", "-4", "addr", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const ifname = root.active ? root.wifi.name : (root.wiredConnected ? root.wired.name : "")
                    const entry = JSON.parse(text).find(i => i.ifname === ifname)
                    root.ip = entry && entry.addr_info.length ? entry.addr_info[0].local : ""
                } catch (e) {
                    root.ip = ""
                }
            }
        }
    }

    function failMessage(reason) {
        switch (reason) {
        case N.ConnectionFailReason.NoSecrets: return "Wrong password (or none given)."
        case N.ConnectionFailReason.WifiAuthTimeout: return "Authentication timed out. Check the password."
        case N.ConnectionFailReason.WifiNetworkLost: return "Network went out of range."
        case N.ConnectionFailReason.WifiClientFailed: return "Couldn't connect. Check the password."
        default: return "Couldn't connect."
        }
    }
}

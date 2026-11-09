// Bluetooth state from BlueZ (Quickshell.Bluetooth, event-driven).
// Used by bar/BluetoothIcon.qml and popups/BluetoothMenu.qml.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth as B
import qs.components

Singleton {
    id: root

    readonly property var adapter: B.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var paired: devices.filter(d => d.paired || d.bonded)
                                         .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var unpaired: devices.filter(d => !d.paired && !d.bonded && d.deviceName.length > 0)
    readonly property var connected: devices.filter(d => d.connected)

    readonly property string glyph: !enabled ? Glyphs.bluetoothOff
                                  : connected.length > 0 ? Glyphs.bluetoothConnected
                                  : Glyphs.bluetooth
    readonly property string summary: !available ? "No Bluetooth adapter"
                                    : !enabled ? "Bluetooth off"
                                    : connected.length === 0 ? "Bluetooth on, nothing connected"
                                    : connected.map(d => d.name + (d.batteryAvailable ? ` (${Math.round(d.battery * 100)}%)` : "")).join(", ")

    function setEnabled(on) { if (adapter) adapter.enabled = on }
    function setDiscovering(on) { if (adapter && adapter.enabled) adapter.discovering = on }

    // Glyph for a device from its BlueZ icon name (audio-headset, input-mouse, ...)
    function deviceGlyph(device) {
        const icon = device.icon || ""
        if (icon.startsWith("audio")) return Glyphs.headphones
        if (icon === "phone") return "󰏲"            // nf-md-phone
        if (icon === "input-mouse") return "󰍽"      // nf-md-mouse
        if (icon === "input-keyboard") return "󰌌"   // nf-md-keyboard
        if (icon === "input-gaming") return "󰊴"     // nf-md-controller
        return Glyphs.bluetooth
    }
}

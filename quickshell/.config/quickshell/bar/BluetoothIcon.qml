// Bluetooth state: off (muted, crossed), on (white), connected (light blue + dot).
// Click -> BluetoothMenu.
import QtQuick
import qs
import qs.components
import qs.popups
import qs.services

BarIcon {
    id: icon
    required property var barWindow
    visible: Bluetooth.available
    // Clean rune in every state; state shows through color + a dot when connected
    glyph: Bluetooth.enabled ? Glyphs.bluetooth : Glyphs.bluetoothOff
    color: !Bluetooth.enabled ? Theme.muted : Bluetooth.connected.length > 0 ? Theme.lightBlue : Theme.text
    badge: Bluetooth.connected.length > 0
    tooltip: Bluetooth.summary
    popup: "bluetooth"
    screenName: barWindow.screen?.name ?? ""

    BluetoothMenu { barWindow: icon.barWindow; anchorItem: icon }
}

// Bluetooth state (off / on / connected). Click -> BluetoothMenu.
import QtQuick
import qs
import qs.popups
import qs.services

BarIcon {
    id: icon
    required property var barWindow
    visible: Bluetooth.available
    glyph: Bluetooth.glyph
    color: Bluetooth.enabled ? Theme.text : Theme.muted
    tooltip: Bluetooth.summary
    popup: "bluetooth"
    screenName: barWindow.screen?.name ?? ""

    BluetoothMenu { barWindow: icon.barWindow; anchorItem: icon }
}

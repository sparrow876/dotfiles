// Wi-Fi / ethernet state. Click -> NetworkMenu.
import QtQuick
import qs
import qs.popups
import qs.services

BarIcon {
    id: icon
    required property var barWindow
    glyph: Network.glyph
    color: Network.wifiEnabled || Network.wiredConnected ? Theme.text : Theme.muted
    tooltip: Network.summary
    popup: "network"
    screenName: barWindow.screen?.name ?? ""

    NetworkMenu { barWindow: icon.barWindow; anchorItem: icon }
}

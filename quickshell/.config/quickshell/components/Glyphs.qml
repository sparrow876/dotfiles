// Every icon glyph the shell uses (Material Design Icons from JetBrainsMono
// Nerd Font, all verified to exist in the installed font). One style everywhere.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property var wifiLevels: ["󰤟", "󰤢", "󰤥", "󰤨"]   // 1..4 bars
    readonly property string wifiNone: "󰤯"
    readonly property string wifiOff: "󰖪"
    readonly property string ethernet: "󰈀"
    readonly property string bluetooth: "󰂯"
    readonly property string bluetoothOff: "󰂲"
    readonly property string bluetoothConnected: "󰂱"
    readonly property string volumeHigh: "󰕾"
    readonly property string volumeMid: "󰖀"
    readonly property string volumeLow: "󰕿"
    readonly property string volumeMuted: "󰖁"
    readonly property string mic: "󰍬"
    readonly property string micOff: "󰍭"
    readonly property string speaker: "󰓃"
    readonly property string headphones: "󰋋"
    readonly property string monitor: "󰍹"
    readonly property string refresh: "󰑐"
    readonly property string lock: "󰌾"
    readonly property string check: "󰄬"
    readonly property string dots: "󰇘"
    readonly property string eye: "󰈈"
    readonly property string eyeOff: "󰈉"
    readonly property string chevronLeft: "󰅁"
    readonly property string chevronRight: "󰅂"
    readonly property string close: "󰅖"
    readonly property string coffee: "󰅶"          // idle inhibitor on
    readonly property string coffeeOutline: "󰛊"   // idle inhibitor off
    readonly property var brightnessLevels: ["󰃞", "󰃟", "󰃠"]   // low, mid, high
    readonly property string bell: "󰂚"
    readonly property string bellOff: "󰂛"
    readonly property string play: "󰐊"
    readonly property string pause: "󰏤"
    readonly property string music: "󰝚"
    readonly property string replay: "󰑙"
}

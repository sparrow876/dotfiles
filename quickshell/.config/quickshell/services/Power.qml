pragma Singleton
// Battery state shared by the bar (bar/Battery.qml) and the stats panel, plus
// the low-battery notifications. Those live here so they fire once, not once
// per bar (one bar per monitor). Event-driven (UPower D-Bus), no polling.
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    // UPower's combined "display device": percentage, state, time left, draw
    readonly property UPowerDevice display: UPower.displayDevice
    // The real battery (BAT0): only it reports health (0-100)
    readonly property UPowerDevice battery: UPower.devices.values.find(d => d.isLaptopBattery) ?? null

    readonly property bool present: display?.isPresent ?? false
    readonly property int percent: Math.round((display?.percentage ?? 0) * 100)
    readonly property bool onAC: !UPower.onBattery
    readonly property bool charging: display?.state === UPowerDeviceState.Charging

    // Low-battery notifications: once per threshold per discharge
    property int lastWarned: 101
    onPercentChanged: {
        if (onAC || !present) return
        if (percent <= 5 && lastWarned > 5) {
            lastWarned = 5
            Quickshell.execDetached(["notify-send", "-u", "critical", "-i", "battery-empty",
                                     "Battery critically low", `${percent}% left. Plug in now.`])
        } else if (percent <= 15 && lastWarned > 15) {
            lastWarned = 15
            Quickshell.execDetached(["notify-send", "-u", "normal", "-i", "battery-caution",
                                     "Battery low", `${percent}% left.`])
        }
    }
    onOnACChanged: if (onAC) lastWarned = 101
}

// Battery: level icon (+ bolt while on AC) and percentage.
// Warn color below 20%, critical below 10% (on battery). Notifications at 15% and 5%.
// Tooltip: time remaining and power draw. Data comes from UPower (event-driven,
// no polling).
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

MouseArea {
    id: root
    readonly property UPowerDevice dev: Power.display
    readonly property bool present: Power.present
    readonly property int percent: Power.percent
    readonly property bool onAC: Power.onAC
    readonly property bool charging: Power.charging
    readonly property color levelColor: !onAC && percent < 10 ? Theme.critical
                                      : !onAC && percent < 20 ? Theme.warn
                                      : Theme.text

    // nf-md-battery_outline .. nf-md-battery (0, 10, ..., 100%)
    readonly property var levelIcons: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    visible: present
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    hoverEnabled: true

    Row {
        id: row
        spacing: 4
        Icon {
            text: root.levelIcons[Math.max(0, Math.min(10, Math.round(root.percent / 10)))]
            color: root.levelColor
            size: 19
            anchors.verticalCenter: parent.verticalCenter
        }
        Icon {
            visible: root.onAC
            text: "󱐋"   // nf-md-lightning_bolt
            color: Theme.lightBlue
            size: 15
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: root.percent + "%"
            color: root.levelColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    function duration(seconds) {
        if (!seconds || seconds <= 0) return ""
        const total = Math.round(seconds / 60)        // never "1 h 60 min"
        const h = Math.floor(total / 60)
        const m = total % 60
        return h > 0 ? `${h} h ${m} min` : `${m} min`
    }

    Tooltip {
        target: root
        text: {
            if (!root.dev) return ""
            const watts = Math.abs(root.dev.changeRate).toFixed(1) + " W"
            if (root.dev.state === UPowerDeviceState.FullyCharged) return "Fully charged (plugged in)"
            if (root.charging) {
                const t = root.duration(root.dev.timeToFull)
                return (t ? `Full in ${t}` : "Charging") + ` · charging at ${watts}`
            }
            if (root.onAC) return "Plugged in, not charging"
            const t = root.duration(root.dev.timeToEmpty)
            return (t ? `${t} left` : "On battery") + ` · using ${watts}`
        }
    }

    // Low-battery notifications: services/Power.qml (once, not per bar)
}

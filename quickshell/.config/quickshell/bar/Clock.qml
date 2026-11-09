// Clock: "HH:MM" + "Mon 09 Nov". Updates once a minute (SystemClock precision),
// so it costs nothing while idle. Click -> calendar popup (added with the popups in step 5).
import QtQuick
import Quickshell
import qs
import qs.components

MouseArea {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    hoverEnabled: true

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property var english: Qt.locale("en_GB")

    Row {
        id: row
        spacing: 8
        StyledText {
            text: Qt.formatTime(clock.date, "HH:mm")
            font.weight: Font.Bold
        }
        StyledText {
            text: clock.date.toLocaleDateString(root.english, "ddd dd MMM")
            color: Theme.muted
        }
    }

    Tooltip {
        target: root
        text: clock.date.toLocaleDateString(root.english, "dddd, d MMMM yyyy")
    }
}

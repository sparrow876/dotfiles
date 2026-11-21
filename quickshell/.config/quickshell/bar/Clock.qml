// Clock: "HH:MM" + "Mon 09 Nov". Updates once a minute (SystemClock precision),
// so it costs nothing while idle. Click -> calendar popup.
import QtQuick
import Quickshell
import qs
import qs.components
import qs.popups
import qs.services

MouseArea {
    id: root
    required property var barWindow
    cursorShape: Qt.PointingHandCursor
    onClicked: Popups.toggle("calendar", barWindow.screen?.name ?? "")
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
        text: Popups.isOpen("calendar", root.barWindow.screen?.name ?? "") ? ""
              : clock.date.toLocaleDateString(root.english, "dddd, d MMMM yyyy")
    }

    CalendarPopup { barWindow: root.barWindow; anchorItem: root }
}

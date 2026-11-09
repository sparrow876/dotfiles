// Calendar popup for the clock: month grid (weeks start Monday), today
// highlighted, ‹ › to change month, scroll to change month, click the title
// to jump back to today.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components

PopupFrame {
    id: cal
    name: "calendar"
    contentWidth: 320

    readonly property var english: Qt.locale("en_GB")
    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()   // 0-11

    function showToday() {
        today = new Date()
        year = today.getFullYear()
        month = today.getMonth()
    }
    onOpened: showToday()
    function shift(delta) {
        const d = new Date(year, month + delta, 1)
        year = d.getFullYear()
        month = d.getMonth()
    }

    // 42 cells (6 weeks), Monday first
    readonly property var cells: {
        const first = new Date(year, month, 1)
        const offset = (first.getDay() + 6) % 7
        const out = []
        for (let i = 0; i < 42; i++) {
            const d = new Date(year, month, 1 - offset + i)
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                isToday: d.toDateString() === today.toDateString()
            })
        }
        return out
    }

    RowLayout {
        Layout.fillWidth: true
        IconButton { glyph: Glyphs.chevronLeft; size: 16; tooltip: "Previous month"; onClicked: cal.shift(-1) }
        MouseArea {
            Layout.fillWidth: true
            implicitHeight: title.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: cal.showToday()
            StyledText {
                id: title
                anchors.centerIn: parent
                text: new Date(cal.year, cal.month, 1).toLocaleDateString(cal.english, "MMMM yyyy")
                font.weight: Font.Bold
            }
        }
        IconButton { glyph: Glyphs.chevronRight; size: 16; tooltip: "Next month"; onClicked: cal.shift(1) }
    }

    GridLayout {
        columns: 7
        columnSpacing: 2
        rowSpacing: 2
        Layout.fillWidth: true

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            delegate: StyledText {
                required property string modelData
                text: modelData
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
        Repeater {
            model: cal.cells
            delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 34
                Rectangle {
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: 16
                    color: modelData.isToday ? Theme.lightBlue : "transparent"
                }
                StyledText {
                    anchors.centerIn: parent
                    text: modelData.day
                    font.weight: modelData.isToday ? Font.Bold : Font.Normal
                    color: modelData.isToday ? Theme.base : modelData.inMonth ? Theme.text : Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.5)
                }
            }
        }
    }

    WheelHandler {
        target: null
        onWheel: event => cal.shift(event.angleDelta.y > 0 ? -1 : 1)
    }
}

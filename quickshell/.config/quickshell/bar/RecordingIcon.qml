// Recording indicator: hidden unless recording or replay mode is on.
//   recording: blinking red dot + elapsed time (+ small replay icon if on)
//   replay only: light-blue replay icon
// Click: stop the recording. Right-click: menu with Microphone and Replay mode.
import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.popups
import qs.services

MouseArea {
    id: root
    required property var barWindow
    readonly property string screenName: barWindow.screen?.name ?? ""

    visible: Recorder.recording || Recorder.replay
    implicitWidth: row.implicitWidth + 4
    implicitHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: event => {
        if (event.button === Qt.RightButton) Popups.toggle("recording", screenName)
        else if (Recorder.recording) Recorder.stop()
        else Popups.toggle("recording", screenName)
    }

    function clock(s) {
        const m = Math.floor(s / 60), sec = s % 60
        return `${m}:${sec < 10 ? "0" : ""}${sec}`
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        // Blinks once a second (driven by the elapsed-time tick, no extra animation)
        Rectangle {
            visible: Recorder.recording
            anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10; radius: 5
            color: Theme.critical
            opacity: Recorder.elapsed % 2 === 0 ? 1 : 0.35
        }
        StyledText {
            visible: Recorder.recording
            anchors.verticalCenter: parent.verticalCenter
            text: root.clock(Recorder.elapsed)
            color: Theme.critical
            font.features: { "tnum": 1 }
        }
        Icon {
            visible: Recorder.replay
            anchors.verticalCenter: parent.verticalCenter
            text: Glyphs.replay
            color: Theme.lightBlue
            size: Recorder.recording ? 15 : 18
        }
    }

    Tooltip {
        target: root
        text: Popups.isOpen("recording", root.screenName) ? ""
              : Recorder.recording ? "Recording · click to stop · right-click for options"
              : "Replay mode on · ALT + CTRL + R saves the last 60 s · right-click for options"
    }

    PopupFrame {
        name: "recording"
        barWindow: root.barWindow
        anchorItem: root
        contentWidth: 320

        StyledText { text: "Screen recording"; font.weight: Font.Bold }
        RowLayout {
            Layout.fillWidth: true
            Icon { text: Recorder.mic ? Glyphs.mic : Glyphs.micOff; color: Recorder.mic ? Theme.lightBlue : Theme.muted; size: 18 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText { text: "Microphone" }
                StyledText { text: "Applies to the next recording"; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall }
            }
            Toggle { checked: Recorder.mic; onToggled: Recorder.toggleMic() }
        }
        RowLayout {
            Layout.fillWidth: true
            Icon { text: Glyphs.replay; color: Recorder.replay ? Theme.lightBlue : Theme.muted; size: 18 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText { text: "Replay mode" }
                StyledText { text: "Keeps the last 60 s · ALT + CTRL + R saves"; color: Theme.muted; font.pixelSize: Theme.fontSizeSmall }
            }
            Toggle { checked: Recorder.replay; onToggled: Recorder.toggleReplay() }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextButton { visible: Recorder.replay; label: "Save last 60 s"; primary: true; onClicked: Recorder.replayKey() }
            Item { Layout.fillWidth: true }
            TextButton { visible: Recorder.recording; label: "Stop recording"; danger: true; onClicked: { Recorder.stop(); Popups.close() } }
        }
    }
}

// Center of the bar: music.
//   playing: ⏸  Artist — Title
//   paused:  ▶  Artist — Title            (muted)
//   nothing: ♪                            (small muted icon)
// Click = play/pause, scroll = next / previous track.
// Long titles are cut at 420px (less if the bar is crowded: Bar.qml sets maxWidth)
// with a soft fade instead of "…" (full title in the tooltip).
import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.components
import qs.services

MouseArea {
    id: root
    // Room the bar can give the module (centered between workspaces and icons)
    property real maxWidth: 100000
    readonly property int maxTitleWidth: Math.max(0, Math.min(420, Math.floor(maxWidth - playIcon.width - row.spacing)))

    implicitWidth: row.implicitWidth
    implicitHeight: 32
    hoverEnabled: true
    cursorShape: Media.hasTrack ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: Media.toggle()

    WheelHandler {
        property real acc: 0
        onWheel: event => {
            acc += event.angleDelta.y
            if (Math.abs(acc) < 120) return
            if (acc < 0) Media.next(); else Media.previous()
            acc = 0
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Icon {
            id: playIcon
            anchors.verticalCenter: parent.verticalCenter
            text: !Media.hasTrack ? Glyphs.music : Media.isPlaying ? Glyphs.pause : Glyphs.play
            color: Media.isPlaying ? Theme.lightBlue : Theme.muted
            size: Media.hasTrack ? 18 : 16
        }

        // Title with a fade-out on the right when it's too long
        Item {
            id: titleBox
            visible: Media.hasTrack && root.maxTitleWidth >= 60
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(title.implicitWidth, root.maxTitleWidth)
            height: title.implicitHeight
            clip: true
            readonly property bool overflowing: title.implicitWidth > root.maxTitleWidth
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            StyledText {
                id: title
                text: Media.label
                color: Media.isPlaying ? Theme.text : Theme.muted
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            layer.enabled: overflowing
            // (QtQuick.Effects' MultiEffect mask didn't apply here; OpacityMask does)
            layer.effect: OpacityMask { maskSource: fadeMask }
        }
        Item {
            id: fadeMask
            width: titleBox.width
            height: titleBox.height
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "white" }
                    GradientStop { position: 0.75; color: "white" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    Tooltip {
        target: root
        text: Media.hasTrack ? `${Media.label}\n${Media.playerName} · click: play/pause · scroll: next/previous`
                             : "Nothing playing"
    }
}

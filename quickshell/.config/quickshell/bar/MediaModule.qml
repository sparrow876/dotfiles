// Center of the bar: music.
//   playing: ⏸  Artist — Title
//   paused:  ▶  Artist — Title            (muted)
//   nothing: ♪                            (small muted icon)
// Click = play/pause, scroll = next / previous track.
// Long titles are cut at 420px (less if the bar is crowded: Bar.qml sets maxWidth)
// with a soft fade instead of "…". Hovering scrolls a cut title to the left in
// an endless loop (marquee); moving the mouse away lets it run on to the start
// and stop there.
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

            // --- marquee: hover scrolls left forever (title, gap, title again,
            // so it wraps seamlessly); leaving keeps going the same way until
            // the start is back in place, then stops. Constant speed.
            readonly property real gap: 48                          // px between the copies
            readonly property real cycle: title.implicitWidth + gap // one full lap
            readonly property real speed: 55                        // px per second
            readonly property bool hovered: root.containsMouse && overflowing

            // The text is drawn once into a texture (layer) and that texture
            // slides by fractions of a pixel: smooth, no 1-px stepping of
            // pixel-snapped text.
            Item {
                id: marquee
                width: strip.implicitWidth
                height: parent.height
                layer.enabled: titleBox.overflowing
                layer.smooth: true
                Row {
                    id: strip
                    spacing: titleBox.gap
                    StyledText {
                        id: title
                        text: Media.label
                        color: Media.isPlaying ? Theme.text : Theme.muted
                        Behavior on color { ColorAnimation { duration: 200 } }
                        onTextChanged: titleBox.reset()   // new track: start at the beginning
                    }
                    StyledText {                          // the copy that follows
                        visible: titleBox.overflowing
                        text: title.text
                        color: title.color
                    }
                }
            }

            function reset() { lap.stop(); finish.stop(); startDelay.stop(); marquee.x = 0 }
            // Run from wherever we are to the end of the lap, then decide:
            // still hovered -> next lap; not hovered -> stop at the start.
            function runToLapEnd() {
                finish.from = marquee.x
                finish.duration = Math.max(1, (cycle + marquee.x) / speed * 1000)
                finish.restart()
            }
            onHoveredChanged: {
                if (hovered) {
                    if (marquee.x === 0 && !finish.running) startDelay.restart()
                } else {
                    startDelay.stop()
                    if (lap.running) { lap.stop(); runToLapEnd() }   // finish this lap, then stop
                }
            }
            onOverflowingChanged: if (!overflowing) reset()

            Timer { id: startDelay; interval: 350; onTriggered: titleBox.runToLapEnd() }
            NumberAnimation {
                id: finish
                target: marquee; property: "x"; to: -titleBox.cycle
                onFinished: {
                    marquee.x = 0                     // the copy is now where the title was
                    if (titleBox.hovered) lap.restart()
                }
            }
            NumberAnimation {
                id: lap
                target: marquee; property: "x"; from: 0; to: -titleBox.cycle
                duration: titleBox.cycle / titleBox.speed * 1000
                loops: Animation.Infinite
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
                id: fadeMaskRect
                anchors.fill: parent
                // right edge always fades (more text follows); left edge while scrolled
                readonly property bool fadeLeft: marquee.x < -1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: fadeMaskRect.fadeLeft ? "transparent" : "white" }
                    GradientStop { position: 0.1;  color: "white" }
                    GradientStop { position: 0.75; color: "white" }
                    GradientStop { position: 1.0;  color: "transparent" }
                }
            }
        }
    }

    Tooltip {
        target: root
        // The title is in the bar (and scrolls on hover): just the player + keys
        readonly property var niceNames: ({ "Mozilla zen": "Zen", "Mozilla Firefox": "Firefox" })
        readonly property string playerName: niceNames[Media.player?.identity ?? ""] ?? (Media.player?.identity || "Player")
        text: Media.hasTrack ? `${playerName} · click: play/pause · scroll: skip`
                             : "Nothing playing"
    }
}

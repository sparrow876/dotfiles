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
            readonly property real fadeZone: 40                     // px of left-edge fade
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
                // 2x texture + mipmaps: sub-pixel steps look evenly soft instead of
                // the letters shimmering between sharp and blurry each frame
                layer.textureSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                layer.mipmap: true
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

            // State: "idle" (at the start), "loop" (hovered), "finishing" (mouse
            // left: run on to the end of this lap, then stop at the start).
            // Driven by FrameAnimation from the real time between frames, so the
            // speed never changes when the compositor sends frames less often
            // (a NumberAnimation advances per frame and visibly slowed down).
            property string mode: "idle"
            property real offset: 0                                 // 0 .. cycle
            property real ramp: 0                                   // 0 -> 1 ease-in at the start
            property real avgDt: 1 / 144                            // smoothed frame time
            onOffsetChanged: marquee.x = -offset

            function reset() { mode = "idle"; startDelay.stop(); offset = 0; ramp = 0; avgDt = 1 / 144 }
            onHoveredChanged: {
                if (hovered) {
                    if (mode === "finishing") mode = "loop"
                    else if (mode === "idle") startDelay.restart()
                } else {
                    startDelay.stop()
                    if (mode === "loop") mode = "finishing"
                }
            }
            onOverflowingChanged: if (!overflowing) reset()

            Timer { id: startDelay; interval: 350; onTriggered: { titleBox.ramp = 0; titleBox.mode = "loop" } }
            FrameAnimation {
                running: titleBox.mode !== "idle"
                onTriggered: {
                    // Even steps: move by a smoothed frame time (frames don't arrive
                    // at perfectly even intervals; stalls over 50 ms are ignored)
                    titleBox.avgDt += (Math.min(frameTime, 0.05) - titleBox.avgDt) * 0.1
                    const dt = titleBox.avgDt
                    titleBox.ramp = Math.min(1, titleBox.ramp + dt / 0.4)
                    const easeIn = titleBox.ramp * titleBox.ramp * (3 - 2 * titleBox.ramp)
                    let next = titleBox.offset + dt * titleBox.speed * easeIn
                    if (next >= titleBox.cycle) {
                        next -= titleBox.cycle                      // the copy took the title's place
                        if (titleBox.mode === "finishing") { titleBox.mode = "idle"; next = 0 }
                    }
                    titleBox.offset = next
                }
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
                // Right edge always fades (more text follows). Left edge: builds up
                // over the first 40 px as the title scrolls out; once the title's
                // end has passed the edge only the empty gap is under it, so it
                // switches off there (invisibly) and the next copy slides in with
                // no fade at all. Needs gap > fadeZone.
                readonly property real fadeLeft: titleBox.offset <= title.implicitWidth
                    ? Math.min(1, titleBox.offset / titleBox.fadeZone) : 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, 1 - fadeMaskRect.fadeLeft) }
                    GradientStop { position: Math.min(0.45, titleBox.fadeZone / Math.max(1, titleBox.width)); color: "white" }
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

// Wallpaper reel (ALT + W): a full-screen overlay.
//   Behind: the focused wallpaper itself, blurred and darkened with a vignette;
//   it crossfades as you move.
//   Front: a reel of parallelogram cards leaning 18° that loops (after the last
//   comes the first). The focused card is wide, bright, outlined light blue
//   with a soft glow, and a glint of light crosses it when it lands. Neighbours
//   are narrower, shorter and dimmer, and the pictures inside them slide a
//   little as the cards move (parallax). Cards fly in when the reel opens.
//   Under the focused card: its name, "n / total" and position pips.
//   ←/→, H/L, Tab, mouse wheel or click: move · Home/End: first/last
//   Enter (or click the focused card): apply · Esc or clicking outside: close
// Applying: the focused card straightens and grows to fill the screen (the
// picture decoded at screen size, so it ends up exactly as awww shows it);
// awww switches the real wallpaper behind it (scripts/wallpaper.sh apply
// --cover <this screen>); then an 18° slanted wipe with a glowing edge sweeps
// the overlay away and the desktop is back with the new wallpaper.
// Every animation runs once: nothing redraws while the reel just sits open.
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PanelWindow {
    id: reel
    required property ShellScreen modelData
    screen: modelData

    property bool open: false             // showing and has the keyboard
    property bool applying: false         // grow + wipe running (keyboard already released)
    property real pos: 0                  // animated focus position (unbounded while looping)
    property int target: 0                // position we're moving to
    readonly property var files: Wallpapers.files
    readonly property int count: files.length
    readonly property bool looping: count >= 5   // fewer cards: wrapping would show the seam, so glide back instead
    readonly property int idx: count > 0 ? ((target % count) + count) % count : 0
    readonly property string focusedFile: files[idx] ?? ""

    readonly property real lean: 0.3249   // tan(18°)
    readonly property int cardH: 380
    readonly property int wideW: 600
    readonly property int narrowW: 270

    property real intro: 0                // 0 -> 1 while opening (each card eases itself)
    property real glint: 0                // 0 -> 1: light crossing the focused card
    property real grow: 0                 // 0 -> 1: focused card fills the screen
    property real wipe: 0                 // 0 -> 1: slanted wipe reveals the desktop
    property bool fullWanted: false       // decode the focused picture at screen size
    property bool fullReady: false        // ...and it's decoded (or failed)
    property bool growDone: false
    property bool awwwDone: false
    property bool revealing: false

    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: false
    // While the wipe plays, clicks go through to the desktop
    mask: applying ? noInput : null
    Region { id: noInput }

    Behavior on pos { id: posAnim; NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }

    // Signed distance of card i from position p, wrapped onto the loop
    function dist(i, p) {
        let d = i - p
        if (looping && count > 0) {
            d = d % count
            if (d < -count / 2) d += count
            else if (d >= count / 2) d -= count
        }
        return d
    }
    function clamp01(v) { return Math.max(0, Math.min(1, v)) }

    function show() {
        Popups.close()
        Wallpapers.refresh()
        stopAll()
        jumpTo(Math.max(0, files.indexOf(Wallpapers.current)))
        settle.stop(); bgTimer.stop()          // the opening animation does both
        intro = 0
        fader.opacity = 0
        showBackdrop(true)
        open = true
        visible = true
        showAnim.restart()
        keys.forceActiveFocus()
    }
    function close() {
        if (!open) return
        open = false
        Overlays.closed("wallpaper", screen.name)
        showAnim.stop()
        hideAnim.restart()
    }
    function stopAll() {
        showAnim.stop(); hideAnim.stop(); growAnim.stop(); wipeAnim.stop()
        glintAnim.stop(); revealDelay.stop(); safety.stop(); settle.stop()
        resetState()
    }
    function resetState() {
        applying = false; revealing = false; growDone = false; awwwDone = false
        grow = 0; wipe = 0; glint = 0
        fullWanted = false; fullReady = false
    }
    function jumpTo(i) {
        posAnim.enabled = false
        target = i
        pos = i
        posAnim.enabled = true
    }
    function move(step) {
        if (count === 0 || applying || step === 0) return
        target = looping ? target + step : ((target + step) % count + count) % count
        pos = target
    }
    function moveToIndex(i) { move(Math.round(dist(i, target))) }

    function apply() {
        // also not while the previous change is still running (the safety timer
        // can reveal before a slow awww finishes): a second run would be ignored
        if (count === 0 || applying || !open || applier.running) return
        const name = focusedFile
        applying = true
        open = false                                  // keyboard back to the apps now
        Overlays.closed("wallpaper", screen.name)
        showAnim.stop(); settle.stop(); glintAnim.stop()
        glint = 0
        fullWanted = true
        growDone = false; awwwDone = false; revealing = false
        Wallpapers.current = name
        applier.command = [Wallpapers.script, "apply", Wallpapers.path(name), "--cover", screen.name]
        applier.running = true
        growAnim.restart()
        safety.restart()
    }
    // The wipe starts once the card fills the screen, its sharp picture is in
    // and awww has switched the real wallpaper behind it
    function maybeReveal() {
        if (!applying || revealing || !growDone || !awwwDone || !fullReady) return
        revealing = true
        safety.stop()
        revealDelay.restart()
    }

    onFullReadyChanged: maybeReveal()   // the sharp picture can be the last thing to arrive
    onTargetChanged: {
        fullWanted = false
        fullReady = false
        settle.restart()
        bgTimer.restart()
    }
    // Landed: decode the sharp picture (so Enter can grow it at once) + glint
    Timer {
        id: settle
        interval: 260
        onTriggered: if (reel.open) { reel.fullWanted = true; glintAnim.restart() }
    }

    Process {
        id: applier
        onExited: { reel.awwwDone = true; reel.maybeReveal() }
    }
    Timer { id: revealDelay; interval: 120; onTriggered: wipeAnim.restart() }   // awww's frame reaches the screen
    // Never stay stuck over the desktop (slow disk, awww hanging)
    Timer {
        id: safety
        interval: 4000
        onTriggered: { reel.growDone = true; reel.awwwDone = true; reel.fullReady = true; reel.maybeReveal() }
    }

    // Opened/closed through services/Overlays.qml (keybind -> IPC -> the
    // focused monitor's overlay). A signal handler, not a binding: close()
    // writes back to Overlays.
    Connections {
        target: Overlays
        function onWallpaperChanged() { Overlays.wallpaper === reel.screen.name ? reel.show() : reel.close() }
    }
    // When the list loads after opening, jump to the current wallpaper
    Connections {
        target: Wallpapers
        function onFilesChanged() {
            if (!reel.open) return
            reel.jumpTo(Math.max(0, reel.files.indexOf(Wallpapers.current)))
            reel.showBackdrop(true)
        }
    }

    // --- backdrop: the focused wallpaper, blurred, crossfading -----------------
    // Two layers: the new one fades in on top, then the old one is dropped.
    component BackdropLayer: Item {
        id: layer
        property string src: ""
        readonly property bool ready: src !== "" && pic.status === Image.Ready
        anchors.fill: parent
        opacity: 0
        // Blurred at 240x135 and scaled up: smooth, and cheap to compute
        Item {
            width: 240; height: 135
            scale: Math.max(layer.width / 240, layer.height / 135)
            transformOrigin: Item.TopLeft
            Image {
                id: pic
                anchors.fill: parent
                source: layer.src
                sourceSize: Qt.size(240, 135)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            FastBlur {
                anchors.fill: parent
                source: pic
                radius: 18
                cached: true
                visible: pic.status === Image.Ready
            }
        }
    }
    property Item bgFront: bgA
    property Item bgPending: null
    Timer { id: bgTimer; interval: 140; onTriggered: reel.showBackdrop(false) }
    function showBackdrop(instant) {
        const src = (visible || instant) && focusedFile ? Wallpapers.thumb(focusedFile) : ""
        finishBackdropFade()
        const front = bgFront, back = front === bgA ? bgB : bgA
        if (instant) {
            front.src = src; front.opacity = 1
            back.opacity = 0
            bgPending = null
            return
        }
        if (front.src === src) return
        back.z = 1; front.z = 0
        back.opacity = 0
        back.src = src
        bgPending = back
        if (back.ready) fadeBackdrop()
    }
    function fadeBackdrop() {
        if (!bgPending) return
        bgFade.layer = bgPending
        bgPending = null
        bgFade.restart()
    }
    function finishBackdropFade() {
        if (!bgFade.running) return
        bgFade.stop()
        bgFade.layer.opacity = 1
        const old = bgFade.layer === bgA ? bgB : bgA
        old.opacity = 0
        bgFront = bgFade.layer
    }
    SequentialAnimation {
        id: bgFade
        property Item layer: null
        NumberAnimation { target: bgFade.layer; property: "opacity"; to: 1; duration: 450; easing.type: Easing.OutCubic }
        ScriptAction {
            script: {
                const old = bgFade.layer === bgA ? bgB : bgA
                old.opacity = 0
                reel.bgFront = bgFade.layer
            }
        }
    }

    // --- keyboard + wheel -------------------------------------------------------
    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            event.accepted = true
            if (reel.applying) return
            switch (event.key) {
            case Qt.Key_Escape: reel.close(); break
            case Qt.Key_Left: case Qt.Key_H: case Qt.Key_Backtab: reel.move(-1); break
            case Qt.Key_Right: case Qt.Key_L: case Qt.Key_Tab: reel.move(1); break
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: reel.apply(); break
            case Qt.Key_Home: reel.moveToIndex(0); break
            case Qt.Key_End: reel.moveToIndex(reel.count - 1); break
            }
        }
    }
    WheelHandler {
        property real acc: 0
        onWheel: event => {
            if (reel.applying) return
            acc += event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (Math.abs(acc) < 120) return
            reel.move(acc > 0 ? -1 : 1)
            acc = 0
        }
    }

    // --- everything visible, inside the wipe ------------------------------------
    // `wiper` is a slanted window onto the overlay: its left edge leans 18°
    // ("/") and slides right during the reveal; left of it the desktop is back.
    // Its content is sheared back, so normally nothing looks slanted.
    Item {
        id: wiper
        readonly property real slant: reel.lean * reel.height
        x: -slant / 2 - 72 + reel.wipe * (reel.width + slant + 144)
        width: reel.width + slant + 144
        height: reel.height
        clip: reel.applying
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, -reel.lean, 0, reel.lean * reel.height / 2,
                                 0, 1, 0, 0,
                                 0, 0, 1, 0,
                                 0, 0, 0, 1)
        }

        Item {
            id: fader
            x: -wiper.x
            width: reel.width
            height: reel.height
            opacity: 0
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, reel.lean, 0, -reel.lean * reel.height / 2,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1)
            }

            // Tint over the blurred screen until the backdrop is in; click closes
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.45)
                MouseArea { anchors.fill: parent; onClicked: reel.close() }
            }

            Item {
                id: backdrop
                anchors.fill: parent
                BackdropLayer { id: bgA; onReadyChanged: if (ready && reel.bgPending === bgA) reel.fadeBackdrop() }
                BackdropLayer { id: bgB; onReadyChanged: if (ready && reel.bgPending === bgB) reel.fadeBackdrop() }
                // darker, with a vignette, so the cards and text stand out
                Rectangle {
                    anchors.fill: parent
                    z: 2
                    color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.30)
                }
                RadialGradient {
                    anchors.fill: parent
                    z: 2
                    horizontalRadius: width * 0.72
                    verticalRadius: height * 0.80
                    gradient: Gradient {
                        GradientStop { position: 0.35; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.85) }
                    }
                }
            }

            Item {
                id: stage
                anchors.fill: parent

                // Empty folder
                Column {
                    visible: reel.count === 0
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "󰸉"; size: 48; color: Theme.muted }
                    StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: "No wallpapers yet"; font.weight: Font.Bold }
                    StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: "Add .jpg, .png or .webp files to ~/Pictures/Wallpapers"; color: Theme.muted }
                }

                Repeater {
                    model: reel.files
                    delegate: Item {
                        id: card
                        required property string modelData
                        required property int index
                        readonly property real d: reel.dist(index, reel.pos)          // distance from focus
                        readonly property real ad: Math.abs(d)
                        readonly property real near: Math.max(0, 1 - ad)              // 1 = focused
                        readonly property bool isFocus: index === reel.idx
                        readonly property real g: isFocus ? reel.grow : 0             // growing to full screen
                        readonly property real away: isFocus ? 0 : reel.grow          // the others fly out
                        // Opening: each card arrives a little after the one nearer the centre
                        readonly property real arrive: {
                            const t = reel.clamp01((reel.intro - 0.09 * Math.min(ad, 4)) / 0.64)
                            return 1 - Math.pow(1 - t, 3)
                        }
                        readonly property real centerX: reel.width / 2 + d * 300 + Math.sign(d) * Math.min(ad, 1) * 160
                        readonly property real edgeFade: 1 - reel.clamp01((Math.abs(centerX - reel.width / 2) - reel.width * 0.30) / (reel.width * 0.18))
                        readonly property real baseW: reel.narrowW + (reel.wideW - reel.narrowW) * near
                        readonly property real baseH: reel.cardH * (0.88 + 0.12 * near)
                        readonly property real baseX: centerX - baseW / 2 + Math.sign(d) * (away * 420 + (1 - arrive) * 140)
                        readonly property real baseY: reel.height / 2 - baseH / 2 - 20 + (1 - arrive) * 110
                        readonly property real sh: reel.lean * (1 - g)                // lean, gone once full screen
                        readonly property real pad: 50 * (1 - g)                      // parallax room
                        readonly property real par: pad * Math.max(-1, Math.min(1, d))

                        x: baseX * (1 - g)
                        y: baseY * (1 - g)
                        width: baseW + (reel.width - baseW) * g
                        height: baseH + (reel.height - baseH) * g
                        z: isFocus ? (reel.applying ? 100 : 11) : 10 - ad
                        opacity: edgeFade * arrive * (1 - away)
                        visible: ad < 4.5 && opacity > 0.01

                        // Lean the card 18° (top to the right) around its centre
                        transform: Matrix4x4 {
                            matrix: Qt.matrix4x4(1, -card.sh, 0, card.sh * card.height / 2,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }

                        // Soft light-blue glow around the focused card
                        RectangularGlow {
                            anchors.fill: frame
                            visible: opacity > 0.01
                            glowRadius: 26
                            spread: 0.12
                            cornerRadius: frame.radius + glowRadius
                            color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.32)
                            opacity: card.near * (1 - card.g)
                        }

                        ClippingRectangle {
                            id: frame
                            anchors.fill: parent
                            radius: 16 * (1 - card.g)
                            color: Theme.surface

                            // The picture, sheared back so it stays upright inside the
                            // leaning card, with room to slide (parallax)
                            Image {
                                id: thumbPic
                                width: card.width + card.sh * card.height + 2 * card.pad
                                height: card.height
                                x: -card.sh * card.height / 2 - card.pad - card.par
                                // decoded only while the reel is open (not kept in memory all day)
                                source: reel.visible ? Wallpapers.thumb(card.modelData) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                sourceSize.width: 720
                                sourceSize.height: 405
                                visible: !fullPic.visible
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, card.sh, 0, -card.sh * card.height / 2,
                                                         0, 1, 0, 0,
                                                         0, 0, 1, 0,
                                                         0, 0, 0, 1)
                                }
                            }
                            // The focused picture at screen size: sharp when it grows
                            Image {
                                id: fullPic
                                width: thumbPic.width
                                height: thumbPic.height
                                x: thumbPic.x
                                source: card.isFocus && reel.fullWanted ? Wallpapers.url(card.modelData) : ""
                                sourceSize: Qt.size(reel.width * (reel.screen?.devicePixelRatio ?? 1),
                                                    reel.height * (reel.screen?.devicePixelRatio ?? 1))
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                mipmap: true          // shown small in the reel before it grows
                                visible: status === Image.Ready
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, card.sh, 0, -card.sh * card.height / 2,
                                                         0, 1, 0, 0,
                                                         0, 0, 1, 0,
                                                         0, 0, 0, 1)
                                }
                                onStatusChanged: if (card.isFocus) reel.fullReady = status === Image.Ready || status === Image.Error
                            }
                            // Neighbours are dimmed
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.base
                                opacity: 0.55 * Math.min(1, card.ad) * (1 - card.g)
                            }
                            // Glint: a band of light crossing the card once when it lands
                            Rectangle {
                                visible: card.isFocus && reel.glint > 0 && reel.glint < 1
                                width: 150
                                height: card.height
                                x: -width + (card.width + 2 * width) * reel.glint
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.17) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                        }
                        // Outline: light blue on the focused card, faint otherwise
                        Rectangle {
                            anchors.fill: parent
                            radius: frame.radius
                            color: "transparent"
                            opacity: 1 - card.g
                            border.width: card.near > 0.5 ? 3 : 1
                            border.color: card.near > 0.5 ? Theme.lightBlue : Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.15)
                        }
                        // Current wallpaper marker
                        Rectangle {
                            visible: card.modelData === Wallpapers.current
                            opacity: 1 - card.g
                            width: 10; height: 10; radius: 5
                            color: Theme.lightBlue
                            border.width: 2
                            border.color: Theme.base
                            x: parent.width - 24; y: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !reel.applying
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.isFocus ? reel.apply() : reel.moveToIndex(card.index)
                        }
                    }
                }

                // Name, position and pips under the focused card
                Column {
                    visible: reel.count > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: reel.height / 2 + reel.cardH / 2 + 6
                    spacing: 10
                    opacity: reel.clamp01((reel.intro - 0.3) / 0.5) * (1 - reel.grow)

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        StyledText {
                            text: reel.focusedFile.replace(/\.[^.]+$/, "")
                            font.weight: Font.Bold
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `${reel.idx + 1} / ${reel.count}`
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                    Row {
                        visible: reel.count <= 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Repeater {
                            model: reel.count
                            delegate: Rectangle {
                                required property int index
                                readonly property bool on: index === reel.idx
                                width: on ? 22 : 6
                                height: 6
                                radius: 3
                                color: on ? Theme.lightBlue : Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.25)
                                Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                    }
                }
                StyledText {
                    visible: reel.count > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 48
                    opacity: reel.clamp01((reel.intro - 0.3) / 0.5) * (1 - reel.grow)
                    text: "←/→ move · Enter apply · Esc close"
                    color: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.7)
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // The wipe's front: a bright line with a soft glow trailing into the overlay
        Item {
            visible: reel.revealing
            width: 72
            height: wiper.height
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.50) }
                    GradientStop { position: 0.35; color: Qt.rgba(Theme.lightBlue.r, Theme.lightBlue.g, Theme.lightBlue.b, 0.16) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
            Rectangle { width: 2; height: parent.height; color: Theme.ice; opacity: 0.9 }
        }
    }

    // --- animations -------------------------------------------------------------
    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: fader; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutQuint }
        NumberAnimation { target: reel; property: "intro"; from: 0; to: 1; duration: 760 }
        SequentialAnimation {
            PauseAnimation { duration: 520 }
            ScriptAction { script: { reel.fullWanted = true; glintAnim.restart() } }
        }
    }
    SequentialAnimation {
        id: hideAnim
        NumberAnimation { target: fader; property: "opacity"; to: 0; duration: 180; easing.type: Easing.InOutCubic }
        ScriptAction { script: { reel.visible = false; reel.resetState() } }
    }
    NumberAnimation {
        id: glintAnim
        target: reel; property: "glint"; from: 0; to: 1
        duration: 700; easing.type: Easing.InOutSine
    }
    NumberAnimation {
        id: growAnim
        target: reel; property: "grow"; from: 0; to: 1
        duration: 620; easing.type: Easing.InOutCubic
        onFinished: { reel.growDone = true; reel.maybeReveal() }
    }
    SequentialAnimation {
        id: wipeAnim
        NumberAnimation { target: reel; property: "wipe"; from: 0; to: 1; duration: 760; easing.type: Easing.InOutCubic }
        ScriptAction { script: { reel.visible = false; reel.resetState() } }
    }
}

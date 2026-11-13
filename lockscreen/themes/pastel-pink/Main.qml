// pastel-pink: pastel pink lock screen + SDDM login screen.
// Written for this repo in qylock's theme format, so the same file runs in:
//  - the lock screen: qylock's lock_shell.qml + its PAM shim provide `sddm`,
//    `userModel`, `sessionModel`, `config` (scripts/lock.sh points it here)
//  - SDDM's greeter (copied to /usr/share/sddm/themes/pastel-pink by
//    system/root-steps/6-login-theme.sh), which provides the same objects.
// Pieces: pastel background (bg.jpg + pink wash, or a gradient), a few faint
// drifting sparkles, a frosted card with clock, avatar, greeting and a
// password pill, plus round restart / power-off buttons.
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root
    width: 1920; height: 1080
    readonly property real s: Math.min(width / 1920, height / 1080)

    // Inside the lock screen there's no real SDDM (no hostName)
    readonly property bool isLockScreen: typeof sddm === "undefined" || sddm.hostName === undefined
    readonly property var cfg: typeof config !== "undefined" ? config : ({})

    // Palette: pastel pink
    readonly property color milk:      "#fff5f9"
    readonly property color blush:     "#ffd6e7"
    readonly property color petal:     "#ffb3cf"
    readonly property color rose:      "#ff86b3"
    readonly property color berry:     "#e0588f"
    readonly property color plum:      "#9b4d73"
    readonly property color lavender:  "#e6d6ff"

    property int userIndex:    (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property bool busy: false
    property string errorText: ""
    property var now: new Date()

    FontLoader { id: roundFont; source: "fonts/Fredoka.ttf" }
    FontLoader { id: softFont;  source: "fonts/Quicksand.ttf" }

    // Read user / session names from the models (works for SDDM and the shim)
    ListView { id: users; model: typeof userModel !== "undefined" ? userModel : null; currentIndex: root.userIndex
               width: 1; height: 1; opacity: 0; z: -100
               delegate: Item { property string login: model.name || ""; property string real: model.realName || model.name || "" } }
    ListView { id: sessions; model: typeof sessionModel !== "undefined" ? sessionModel : null; currentIndex: root.sessionIndex
               width: 1; height: 1; opacity: 0; z: -100
               delegate: Item { property string label: model.name || "" } }
    readonly property string userLogin: users.currentItem && users.currentItem.login !== "" ? users.currentItem.login
                                        : (typeof userModel !== "undefined" ? userModel.lastUser : "")
    readonly property string userName: users.currentItem && users.currentItem.real !== "" ? users.currentItem.real : userLogin

    function login() {
        if (busy || pass.text.length === 0) return
        busy = true
        errorText = ""
        busyGuard.restart()
        sddm.login(userLogin, pass.text, sessionIndex)
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            root.busy = false
            busyGuard.stop()
            const why = (typeof sddm.lastError === "string" && sddm.lastError !== "") ? sddm.lastError : ""
            root.errorText = why !== "" ? why.toLowerCase() : "oops, wrong password, try again"
            pass.text = ""
            shake.restart()
            pass.forceActiveFocus()
        }
        function onLoginSucceeded() { busyGuard.stop() }
    }
    // Never stay "busy" forever if no answer comes back
    Timer { id: busyGuard; interval: 25000; onTriggered: { root.busy = false; root.errorText = "no answer, try again" } }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Timer { interval: 300; running: true; onTriggered: pass.forceActiveFocus() }

    Keys.onEscapePressed: { pass.text = ""; root.errorText = "" }

    // ---- background ---------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#ffd9ea" }
            GradientStop { position: 0.55; color: "#f8c6dc" }
            GradientStop { position: 1.0; color: "#e4d2ff" }
        }
    }
    Image {
        id: bg
        anchors.fill: parent
        source: root.cfg.background ? root.cfg.background : "bg.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
    }
    Rectangle {   // pink wash: makes any picture pastel
        anchors.fill: parent
        visible: bg.visible
        opacity: root.cfg.wash !== undefined ? parseFloat(root.cfg.wash) : 0.35
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#ffe3ef" }
            GradientStop { position: 1.0; color: "#f3c4dc" }
        }
    }

    // ---- faint drifting sparkles ---------------------------------------------
    Repeater {
        model: 12
        delegate: Text {
            id: bit
            required property int index
            readonly property var glyphs: ["✦", "⋆"]
            readonly property real seed: ((index * 7919) % 97) / 97
            text: glyphs[index % glyphs.length]
            color: index % 3 === 0 ? root.milk : (index % 3 === 1 ? root.petal : root.lavender)
            font.pixelSize: (22 + seed * 30) * root.s
            opacity: 0
            x: root.width * (((index * 53) % 100) / 100)
            y: root.height + 40
            SequentialAnimation {
                running: true
                PauseAnimation { duration: bit.seed * 16000 }   // staggered start
            ParallelAnimation {
                loops: Animation.Infinite
                NumberAnimation { target: bit; property: "y"; from: root.height + 40; to: -60
                                  duration: 14000 + bit.seed * 12000 }
                SequentialAnimation {
                    NumberAnimation { target: bit; property: "opacity"; from: 0; to: 0.35 + bit.seed * 0.3; duration: 2500 }
                    PauseAnimation  { duration: 9000 + bit.seed * 9000 }
                    NumberAnimation { target: bit; property: "opacity"; to: 0; duration: 2500 }
                }
                SequentialAnimation {
                    loops: 3
                    NumberAnimation { target: bit; property: "rotation"; from: -12; to: 12; duration: 2400; easing.type: Easing.InOutSine }
                    NumberAnimation { target: bit; property: "rotation"; from: 12; to: -12; duration: 2400; easing.type: Easing.InOutSine }
                }
            }
            }
        }
    }

    // ---- date pill (top) ------------------------------------------------------
    Rectangle {
        anchors.top: parent.top; anchors.topMargin: 56 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: dateText.implicitWidth + 56 * root.s; height: 52 * root.s
        radius: 14 * root.s
        color: Qt.rgba(1, 1, 1, 0.55)
        border.color: Qt.rgba(1, 1, 1, 0.8); border.width: 1.5 * root.s
        Text {
            id: dateText
            anchors.centerIn: parent
            text: Qt.formatDate(root.now, "dddd, d MMMM").toLowerCase()
            font.family: softFont.name; font.pixelSize: 22 * root.s; font.weight: Font.DemiBold
            color: root.plum
        }
    }

    // ---- the card --------------------------------------------------------------
    Item {
        id: cardBox
        width: 560 * root.s; height: 620 * root.s
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 20 * root.s

        DropShadow {
            anchors.fill: card; source: card
            radius: 40; samples: 61; verticalOffset: 14 * root.s
            color: Qt.rgba(0.78, 0.33, 0.52, 0.28)
        }
        Rectangle {
            id: card
            anchors.fill: parent
            radius: 20 * root.s
            color: Qt.rgba(1, 0.97, 0.985, 0.72)
            border.color: Qt.rgba(1, 1, 1, 0.9); border.width: 2 * root.s

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top; anchors.topMargin: 44 * root.s
                spacing: 10 * root.s

                Item {   // clock, with a soft white "sticker" shadow
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: clock.implicitWidth; height: clock.implicitHeight
                    Text {
                        x: 0; y: 5 * root.s
                        text: clock.text; font: clock.font
                        color: root.milk
                    }
                    Text {
                        id: clock
                        text: Qt.formatTime(root.now, "HH:mm")
                        font.family: roundFont.name; font.pixelSize: 118 * root.s; font.weight: Font.Medium
                        color: root.rose
                    }
                }

                Item { width: 1; height: 6 * root.s }

                // avatar: a pink circle with the first letter
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 118 * root.s; height: 118 * root.s
                    Rectangle {
                        anchors.fill: parent; radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.petal }
                            GradientStop { position: 1.0; color: root.lavender }
                        }
                        border.color: root.milk; border.width: 5 * root.s
                        Text {
                            anchors.centerIn: parent
                            text: root.userName.length > 0 ? root.userName.charAt(0).toUpperCase() : ""
                            font.family: roundFont.name; font.pixelSize: 58 * root.s; font.weight: Font.DemiBold
                            color: root.milk
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "hi, " + root.userName.toLowerCase()
                    font.family: roundFont.name; font.pixelSize: 34 * root.s; font.weight: Font.Medium
                    color: root.berry
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isLockScreen ? "welcome back, type your password to unlock" : "type your password to log in"
                    font.family: softFont.name; font.pixelSize: 18 * root.s; font.weight: Font.DemiBold
                    color: root.plum; opacity: 0.75
                }

                Item { width: 1; height: 12 * root.s }

                // password pill + go button
                Item {
                    id: passRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 420 * root.s; height: 66 * root.s
                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: passRow; property: "anchors.horizontalCenterOffset"; to: -14 * root.s; duration: 60 }
                        NumberAnimation { target: passRow; property: "anchors.horizontalCenterOffset"; to: 14 * root.s; duration: 60 }
                        NumberAnimation { target: passRow; property: "anchors.horizontalCenterOffset"; to: -9 * root.s; duration: 60 }
                        NumberAnimation { target: passRow; property: "anchors.horizontalCenterOffset"; to: 9 * root.s; duration: 60 }
                        NumberAnimation { target: passRow; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
                    }
                    Rectangle {
                        id: pill
                        anchors.left: parent.left; anchors.right: goButton.left; anchors.rightMargin: 12 * root.s
                        height: parent.height; radius: 14 * root.s
                        color: root.milk
                        border.width: 2.5 * root.s
                        border.color: root.errorText !== "" ? root.berry : (pass.activeFocus ? root.rose : root.blush)
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        TextInput {
                            id: pass
                            anchors.fill: parent
                            anchors.leftMargin: 28 * root.s; anchors.rightMargin: 28 * root.s
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password; passwordCharacter: "•"
                            font.family: softFont.name; font.pixelSize: 24 * root.s; font.letterSpacing: 4 * root.s
                            color: root.rose; selectionColor: root.petal
                            clip: true; focus: true
                            enabled: !root.busy
                            onAccepted: root.login()
                            onTextEdited: root.errorText = ""
                            Keys.onEscapePressed: { text = ""; root.errorText = "" }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left; anchors.leftMargin: 30 * root.s
                            visible: pass.text.length === 0
                            text: root.busy ? "checking…" : "password"
                            font.family: softFont.name; font.pixelSize: 21 * root.s; font.weight: Font.DemiBold
                            color: root.petal
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: pass.forceActiveFocus() }
                    }
                    Rectangle {
                        id: goButton
                        anchors.right: parent.right
                        width: parent.height; height: parent.height; radius: 14 * root.s
                        color: goMa.containsMouse ? root.berry : root.rose
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: "➜"
                            color: root.milk; font.pixelSize: 28 * root.s
                            opacity: root.busy ? 0.5 : 1
                        }
                        MouseArea { id: goMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
                    }
                }

                Text {   // errors / caps lock
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 440 * root.s
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.errorText !== "" ? root.errorText
                          : ((typeof keyboard !== "undefined" && keyboard.capsLock) ? "caps lock is on ⇪" : "")
                    font.family: softFont.name; font.pixelSize: 18 * root.s; font.weight: Font.Bold
                    color: root.berry
                }
            }
        }
    }

    // ---- session (login screen only) -------------------------------------------
    Rectangle {
        visible: !root.isLockScreen && sessions.count > 1
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.margins: 40 * root.s
        width: sessText.implicitWidth + 48 * root.s; height: 56 * root.s; radius: 14 * root.s
        color: sessMa.containsMouse ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.6)
        Text {
            id: sessText
            anchors.centerIn: parent
            text: (sessions.currentItem ? sessions.currentItem.label.toLowerCase() : "session")
            font.family: softFont.name; font.pixelSize: 20 * root.s; font.weight: Font.DemiBold
            color: root.plum
        }
        MouseArea {
            id: sessMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessions.count
        }
    }

    // ---- restart / power off ----------------------------------------------------
    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 40 * root.s
        spacing: 16 * root.s
        Repeater {
            model: [
                { glyph: "\u{f0709}", tip: "restart",   act: "reboot" },   // nf-md-restart
                { glyph: "\u{f0425}", tip: "power off", act: "powerOff" }  // nf-md-power
            ]
            delegate: Rectangle {
                id: btn
                required property var modelData
                width: 60 * root.s; height: width; radius: 14 * root.s
                color: btnMa.containsMouse ? root.milk : Qt.rgba(1, 1, 1, 0.6)
                border.color: btnMa.containsMouse ? root.rose : "transparent"; border.width: 2 * root.s
                Text {
                    anchors.centerIn: parent
                    text: btn.modelData.glyph
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 26 * root.s
                    color: root.berry
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top; anchors.bottomMargin: 8 * root.s
                    visible: btnMa.containsMouse
                    text: btn.modelData.tip
                    font.family: softFont.name; font.pixelSize: 16 * root.s; font.weight: Font.Bold
                    color: root.plum
                }
                MouseArea {
                    id: btnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: if (typeof sddm !== "undefined") sddm[btn.modelData.act]()
                }
            }
        }
    }
}

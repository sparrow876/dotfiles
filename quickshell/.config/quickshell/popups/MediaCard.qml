// Now-playing card: click the music in the bar.
//   blurred album art behind the cover, title / artist / album, the player,
//   seek bar (drag or click; only if the player allows seeking) with times,
//   shuffle · previous · play/pause · next · repeat (shuffle/repeat only when
//   the player supports them).
// The position is refreshed once a second, only while the card is open and
// music plays (MPRIS doesn't push position updates).
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PopupFrame {
    id: card
    name: "media"
    contentWidth: 380

    readonly property var p: Media.player
    readonly property string art: p?.trackArtUrl ?? ""
    readonly property bool canSeek: (p?.canSeek ?? false) && (p?.positionSupported ?? false)
    readonly property real length: (p?.lengthSupported ?? false) ? (p?.length ?? 0) : 0
    readonly property var niceNames: ({ "Mozilla zen": "Zen", "Mozilla Firefox": "Firefox" })
    readonly property string playerName: niceNames[p?.identity ?? ""] ?? (p?.identity || "Player")

    function fmt(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0))
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0")
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`
    }

    onOpened: card.p?.positionChanged()
    Timer {
        interval: 1000
        repeat: true
        running: card.visible && Media.isPlaying && (card.p?.positionSupported ?? false)
        onTriggered: card.p.positionChanged()
    }

    // --- nothing playing ------------------------------------------------------
    ColumnLayout {
        visible: !Media.hasTrack
        Layout.fillWidth: true
        Layout.topMargin: 10
        Layout.bottomMargin: 10
        spacing: 6
        Icon { Layout.fillWidth: true; text: Glyphs.music; size: 34; color: Theme.overlay }
        StyledText { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Nothing playing"; color: Theme.muted }
    }

    // --- header: cover + text over the blurred cover --------------------------
    Item {
        visible: Media.hasTrack
        Layout.fillWidth: true
        implicitHeight: 112

        ClippingRectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.45)
            Image {
                id: artBg
                width: card.contentWidth; height: 112
                source: card.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            FastBlur {
                width: card.contentWidth; height: 112
                source: artBg
                radius: 56
                opacity: 0.55
                visible: artBg.status === Image.Ready
            }
            // keeps white text readable over any cover
            Rectangle {
                width: card.contentWidth; height: 112
                color: Qt.rgba(Theme.base.r, Theme.base.g, Theme.base.b, 0.35)
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            ClippingRectangle {
                implicitWidth: 88; implicitHeight: 88
                radius: 10
                color: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.8)
                Image {
                    id: cover
                    width: 88; height: 88
                    source: card.art
                    sourceSize: Qt.size(176, 176)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Icon {
                    visible: cover.status !== Image.Ready
                    x: (88 - width) / 2; y: (88 - height) / 2
                    text: Glyphs.music
                    size: 30
                    color: Theme.muted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                spacing: 2
                StyledText {
                    text: Media.title
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                StyledText {
                    visible: text !== ""
                    text: Media.artist
                    color: Theme.ice
                    font.pixelSize: Theme.fontSizeSmall + 1
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                StyledText {
                    visible: text !== ""
                    text: card.p?.trackAlbum ?? ""
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                StyledText {
                    Layout.topMargin: 2
                    text: card.playerName
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall - 2
                }
            }
        }
    }

    // --- seek bar + times -------------------------------------------------------
    ColumnLayout {
        visible: Media.hasTrack && card.length > 0
        Layout.fillWidth: true
        spacing: 2
        Slider {
            Layout.fillWidth: true
            enabled: card.canSeek
            value: card.length > 0 ? Math.min(1, (card.p?.position ?? 0) / card.length) : 0
            onMoved: v => { if (card.canSeek) card.p.position = v * card.length }
        }
        RowLayout {
            Layout.fillWidth: true
            StyledText { text: card.fmt(card.p?.position ?? 0); color: Theme.muted; font.pixelSize: Theme.fontSizeSmall - 1 }
            Item { Layout.fillWidth: true }
            StyledText { text: card.fmt(card.length); color: Theme.muted; font.pixelSize: Theme.fontSizeSmall - 1 }
        }
    }

    // --- controls ---------------------------------------------------------------
    RowLayout {
        visible: Media.hasTrack
        Layout.alignment: Qt.AlignHCenter
        spacing: 18

        IconButton {
            visible: card.p?.shuffleSupported ?? false
            glyph: "󰒝"   // shuffle
            size: 16
            color: (card.p?.shuffle ?? false) ? Theme.lightBlue : Theme.muted
            tooltip: (card.p?.shuffle ?? false) ? "Shuffle: on" : "Shuffle: off"
            onClicked: card.p.shuffle = !card.p.shuffle
        }
        IconButton {
            glyph: "󰒮"   // previous
            size: 20
            color: (card.p?.canGoPrevious ?? false) ? Theme.text : Theme.overlay
            tooltip: "Previous"
            onClicked: Media.previous()
        }
        // play / pause: a filled circle
        MouseArea {
            implicitWidth: 46; implicitHeight: 46
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: Media.toggle()
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: parent.containsMouse ? Theme.ice : Theme.lightBlue
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Icon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: Media.isPlaying ? 0 : 2   // optical centre of ▶
                text: Media.isPlaying ? Glyphs.pause : Glyphs.play
                size: 22
                color: Theme.base
            }
        }
        IconButton {
            glyph: "󰒭"   // next
            size: 20
            color: (card.p?.canGoNext ?? false) ? Theme.text : Theme.overlay
            tooltip: "Next"
            onClicked: Media.next()
        }
        IconButton {
            readonly property int loop: card.p?.loopState ?? MprisLoopState.None
            visible: card.p?.loopSupported ?? false
            glyph: loop === MprisLoopState.Track ? "󰑘" : "󰑖"   // repeat one / repeat
            size: 16
            color: loop === MprisLoopState.None ? Theme.muted : Theme.lightBlue
            tooltip: loop === MprisLoopState.Track ? "Repeat: this track" : loop === MprisLoopState.Playlist ? "Repeat: all" : "Repeat: off"
            // off -> all -> this track -> off
            onClicked: card.p.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                                        : loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
        }
    }
}

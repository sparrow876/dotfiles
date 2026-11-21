// Blue Ice colours, fonts and sizes for the shell (static file, edit directly).
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // Palette
    readonly property color base: "#0d1b2a"
    readonly property color surface: "#1b263b"
    readonly property color overlay: "#2b3a55"
    readonly property color blue: "#415a77"
    readonly property color lightBlue: "#7fb3ff"
    readonly property color ice: "#cfe8ff"
    readonly property color text: "#f4f8ff"
    readonly property color muted: "#9fb3c8"
    readonly property color warn: "#f2c66d"
    readonly property color critical: "#ef6f7a"
    // Bar gradient (symmetric): rose ends -> lavender -> navy centre. Deep,
    // mostly opaque tones: pastels went whitish under the blur.
    readonly property color barRose: Qt.rgba(0.40, 0.22, 0.38, 0.88)      // #66385f dusty rose
    readonly property color barLavender: Qt.rgba(0.25, 0.23, 0.45, 0.85)  // #403b73 deep lavender
    readonly property color barCentre: Qt.rgba(surface.r, surface.g, surface.b, 0.82)

    // Frosted glass surface (surface color at glassAlpha)
    readonly property real glassAlpha: 0.75
    readonly property color glass: Qt.rgba(surface.r, surface.g, surface.b, glassAlpha)

    // Shape and spacing
    readonly property int rounding: 14
    readonly property int gapsIn: 6
    readonly property int gapsOut: 12

    // Fonts
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property string fontCjk: "Noto Sans CJK JP"
    readonly property int fontSize: 15
    readonly property int fontSizeSmall: 13
}

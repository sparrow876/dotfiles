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
    // Bar gradient, "deep glacier" (symmetric): teal ends -> steel blue ->
    // indigo centre. Picked in OKLCH at the same perceived lightness
    // (L 0.335, chroma ~0.06, hue 215 -> 248 -> 270), so only the hue glides
    // and the centre doesn't look like a dark dip (equal HSL lightness still
    // made the blue centre look darker). Nearly opaque: the blur washed out
    // lighter/translucent tones.
    readonly property color barEdge: Qt.rgba(0.000, 0.244, 0.290, 0.93)   // #003e4a teal
    readonly property color barMid: Qt.rgba(0.101, 0.223, 0.333, 0.93)    // #1a3955 steel blue
    readonly property color barCentre: Qt.rgba(0.164, 0.206, 0.344, 0.93) // #2a3458 indigo

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

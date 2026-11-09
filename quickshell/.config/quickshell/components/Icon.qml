// A Nerd Font glyph used as an icon (the shell uses Material Design icons from
// JetBrainsMono Nerd Font everywhere, so all icons share one style).
import QtQuick
import qs

StyledText {
    property real size: 18
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    Behavior on color { ColorAnimation { duration: 180 } }
}

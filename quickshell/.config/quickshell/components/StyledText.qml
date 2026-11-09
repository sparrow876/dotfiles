// Text in the shell's font and default color. Use everywhere instead of Text.
import QtQuick
import qs

Text {
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: 13
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}

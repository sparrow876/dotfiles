// Text in the shell's font and default color. Use everywhere instead of Text.
// Plain text by default: song titles, SSIDs, device names and notification
// summaries come from outside and must never be rendered as markup (Qt's
// default AutoText would load <img src="https://...">).
import QtQuick
import qs

Text {
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
    textFormat: Text.PlainText
}

// Layout mode button: spaced (gaps, rounded, floating bar) <-> compact
// (i3-style, no gaps, square, bar on the top edge). Click or ALT + G.
// The glyph shows what a click does: expand (go compact) / collapse (go spaced).
import QtQuick
import qs
import qs.components
import qs.services

BarIcon {
    glyph: LayoutMode.compact ? "󰁂" : "󰁌"   // arrow-collapse-all / arrow-expand-all
    color: LayoutMode.compact ? Theme.lightBlue : Theme.text
    tooltip: LayoutMode.compact
             ? "Compact layout (no gaps). Click or ALT + G for the spaced, rounded look."
             : "Spaced layout. Click or ALT + G for compact: no gaps, square windows, bar on the edge."
    onClicked: event => { if (event.button === Qt.LeftButton) LayoutMode.toggle() }
}

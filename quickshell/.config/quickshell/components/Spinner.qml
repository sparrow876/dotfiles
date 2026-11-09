// Spinning refresh glyph, shown while something is in progress.
import QtQuick
import qs

Icon {
    id: root
    property bool running: true
    text: Glyphs.refresh
    color: Theme.lightBlue
    RotationAnimator on rotation {
        running: root.running && root.visible
        from: 0; to: 360
        duration: 900
        loops: Animation.Infinite
    }
}

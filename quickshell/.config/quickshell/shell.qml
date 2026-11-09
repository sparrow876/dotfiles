// Quickshell entry point. Each feature lives in its own folder and is imported
// with `import qs.<folder>`. Theme colors/fonts: Theme.qml (generated from the palette).
import QtQuick
import Quickshell
import qs.bar

ShellRoot {
    // One bar per monitor
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }
}

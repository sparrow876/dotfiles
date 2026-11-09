//@ pragma IconTheme Papirus-Dark
// Quickshell entry point. Each feature lives in its own folder and is imported
// with `import qs.<folder>`. Theme colors/fonts: Theme.qml (generated from the palette).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
import qs.notifications
import qs.osd
import qs.panel
import qs.services

ShellRoot {
    // One bar per monitor
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    // Volume / brightness / mic / idle-inhibitor indicator (bottom-center)
    Variants {
        model: Quickshell.screens
        delegate: Osd {}
    }

    // System stats panel (ALT + S): qs ipc call panel toggle
    Variants {
        model: Quickshell.screens
        delegate: StatsPanel {}
    }

    // Notification popups (top-right)
    Variants {
        model: Quickshell.screens
        delegate: NotificationPopups {}
    }

    // Control popups from outside (keybinds, scripts):
    //   qs ipc call popups toggle network|bluetooth|audio|calendar
    //   qs ipc call popups close
    IpcHandler {
        target: "popups"
        function toggle(name: string): void { Popups.toggle(name, Hyprland.focusedMonitor?.name ?? "") }
        function close(): void { Popups.close() }
    }
}

//@ pragma IconTheme Papirus-Dark
// Quickshell entry point. Each feature lives in its own folder and is imported
// with `import qs.<folder>`. Theme colors/fonts: Theme.qml (generated from the palette).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.bar
import qs.idle
import qs.notifications
import qs.osd
import qs.panel
import qs.powermenu
import qs.wallpaper
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

    // Power menu (ALT + Escape): qs ipc call powermenu toggle
    Variants {
        model: Quickshell.screens
        delegate: PowerMenu {}
    }

    // Wallpaper reel (ALT + W): qs ipc call wallpaper toggle
    Variants {
        model: Quickshell.screens
        delegate: WallpaperReel {}
    }

    // Idle screen (hypridle, 4 min): qs ipc call idlescreen enter|leave
    Variants {
        model: Quickshell.screens
        delegate: IdleScreen {}
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
        function toggle(name: string): void { Popups.toggle(name, Hyprland.focusedMonitor?.name ?? "", false) }
        function close(): void { Popups.close() }
    }
}

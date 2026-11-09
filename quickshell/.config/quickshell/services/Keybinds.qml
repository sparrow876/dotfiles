// Keybinds for the cheat sheet, straight from Hyprland (`hyprctl binds -j`),
// grouped and made readable by scripts/keybinds.jq (the same program builds the
// README table, so both always match). Re-read every time the sheet opens.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var groups: []        // [{ category, items: [{ action, keys: [...] }] }]

    function refresh() { if (!proc.running) proc.running = true }

    Process {
        id: proc
        command: ["sh", "-c", `hyprctl binds -j | jq -c -f "${Quickshell.env("HOME")}/dotfiles/scripts/keybinds.jq"`]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.groups = JSON.parse(text) } catch (e) { console.warn("keybinds: bad JSON", e) }
            }
        }
    }
}

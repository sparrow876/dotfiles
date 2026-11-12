// Wallpapers in ~/Pictures/Wallpapers (jpg, png, webp) for the reel (ALT + W).
// Thumbnails come from ~/.cache/wallpaper-thumbs (scripts/wallpaper.sh thumbs,
// only rebuilt for new/changed files), so opening the reel is instant.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/wallpaper-thumbs"
    readonly property string script: Quickshell.env("HOME") + "/dotfiles/scripts/wallpaper.sh"

    property var files: []          // file names, natural order (w1, w2, ..., w10)
    property string current: ""     // file name of the current wallpaper
    property int thumbsVersion: 0   // bumps when thumbnails were (re)built

    // URL-encoded, so file names with # ? % or spaces still load
    function thumb(name) {
        const path = `${thumbDir}/${name}.jpg`.split("/").map(encodeURIComponent).join("/")
        return `file://${path}?v=${thumbsVersion}`
    }
    function path(name) { return `${dir}/${name}` }

    // List files + current wallpaper (fast), then refresh thumbnails in the background
    function refresh() {
        lister.running = true
        if (!thumbs.running) thumbs.running = true
    }
    function apply(name) { Quickshell.execDetached([script, "apply", path(name)]); current = name }

    Process {
        id: lister
        command: ["sh", "-c", `cd "${root.dir}" 2>/dev/null || exit 0
            find . -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf '%f\\n' | sort -V   # natural order: w2 before w10
            printf '@current=%s\\n' "$(basename "$(readlink current 2>/dev/null)" 2>/dev/null)"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l)
                root.current = (lines.find(l => l.startsWith("@current=")) ?? "@current=").substring(9)
                const files = lines.filter(l => !l.startsWith("@current="))
                // Same list as before: keep it (reassigning rebuilds every card)
                if (JSON.stringify(files) !== JSON.stringify(root.files)) root.files = files
            }
        }
    }
    Process {
        id: thumbs
        command: [root.script, "thumbs"]
        // Reload the images only if some thumbnail was actually (re)built
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /changed=(\d+)/.exec(text)
                if (!m || Number(m[1]) > 0) root.thumbsVersion++
            }
        }
    }

    Component.onCompleted: refresh()

    IpcHandler {
        target: "wallpapers"
        function refresh(): void { root.refresh() }
        function list(): string { return root.files.join("\n") + `\ncurrent: ${root.current}` }
    }
}

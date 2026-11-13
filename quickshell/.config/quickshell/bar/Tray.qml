// System tray (StatusNotifierItem apps: ProtonVPN, Steam, Teams, Discord, Claude...).
// Left click: activate (or open the menu if the app only has a menu)
// Right click: themed app menu (TrayMenu.qml)   Middle click: secondary action
// Scroll: forwarded to the app
// Drag an icon left/right and drop it to change the order. The order is saved
// (by app id) in ~/.local/state/quickshell/by-shell/<id>/tray-order.json and
// survives restarts; apps not in it yet go at the end. Pomoclock is always
// last (right next to the coffee cup) and can't be dragged.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.components

Row {
    id: root
    required property var barWindow
    spacing: 10
    visible: SystemTray.items.values.length > 0

    readonly property string pinnedLast: "io.github.pomoclock.Pomoclock"
    function key(item) { return item ? (item.id || item.title || "") : "" }

    // Items in display order: saved order first, new apps after (in the order
    // they appeared), the pinned one at the very end.
    readonly property var ordered: {
        const order = store.order
        const rank = k => { const i = order.indexOf(k); return i < 0 ? 1e6 : i }
        return SystemTray.items.values
            .map((item, i) => ({ item, i }))
            .sort((a, b) => {
                const pa = key(a.item) === pinnedLast, pb = key(b.item) === pinnedLast
                if (pa !== pb) return pa ? 1 : -1
                return (rank(key(a.item)) - rank(key(b.item))) || (a.i - b.i)
            })
            .map(x => x.item)
    }

    // Move the dragged item to position `to` (among the movable items) and save.
    // Keys of apps that aren't running right now keep their place at the end.
    function moveTo(item, to) {
        const keys = ordered.map(key).filter(k => k !== pinnedLast)
        const from = keys.indexOf(key(item))
        if (from < 0) return
        keys.splice(from, 1)
        keys.splice(Math.max(0, Math.min(to, keys.length)), 0, key(item))
        store.order = keys.concat(store.order.filter(k => !keys.includes(k) && k !== pinnedLast))
    }

    FileView {
        id: orderFile
        path: Quickshell.statePath("tray-order.json")
        printErrors: false            // no file yet = default order
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: store
            property var order: []
        }
    }

    // Smoothly slide icons into their new places
    move: Transition { NumberAnimation { properties: "x"; duration: 180; easing.type: Easing.OutQuint } }

    TrayMenu {
        id: menu
        barWindow: root.barWindow
    }

    Repeater {
        id: repeater
        model: ScriptModel { values: root.ordered }

        delegate: MouseArea {
            id: slot
            required property SystemTrayItem modelData
            required property int index
            // Pomoclock draws its tray icon as a wide pill (170x27), so it gets
            // a slot about six icons wide instead of the usual 20x20 square.
            readonly property bool wide: root.key(modelData) === root.pinnedLast
            readonly property bool movable: root.key(modelData) !== root.pinnedLast
            width: wide ? 170 : 20
            height: wide ? 27 : 20
            anchors.verticalCenter: parent.verticalCenter
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            preventStealing: dragging
            z: dragging ? 10 : 0

            // --- drag to reorder ---------------------------------------------
            property real pressX: 0          // in the tray's coordinates (stable while the icon moves)
            property real dragX: 0
            property bool dragging: false
            property bool justDragged: false
            transform: Translate { x: slot.dragging ? slot.dragX : 0 }

            onPressed: event => {
                pressX = slot.mapToItem(root, event.x, event.y).x; dragX = 0; justDragged = false
            }
            onPositionChanged: event => {
                if (!pressed || !movable || !(pressedButtons & Qt.LeftButton)) return
                // mapToItem includes the drag offset, so this is the real
                // cursor position: no jitter from the icon moving under it
                const dx = slot.mapToItem(root, event.x, event.y).x - pressX
                if (!dragging && Math.abs(dx) > 8) dragging = true
                if (dragging) dragX = dx
            }
            onCanceled: { dragging = false; dragX = 0 }
            onReleased: {
                if (!dragging) return
                // Drop position = how many other movable icons sit left of our centre
                const centre = slot.x + slot.width / 2 + dragX
                let to = 0
                for (let i = 0; i < repeater.count; i++) {
                    const other = repeater.itemAt(i)
                    if (!other || other === slot || !other.movable) continue
                    if (other.x + other.width / 2 < centre) to++
                }
                dragging = false
                justDragged = true
                root.moveTo(modelData, to)
            }

            IconImage {
                visible: !slot.wide
                anchors.fill: parent
                source: slot.wide ? "" : slot.modelData.icon
                implicitSize: 20
                mipmap: true
                opacity: slot.dragging ? 0.7 : slot.containsMouse ? 1 : 0.9
            }

            // IconImage always requests a square image (and Quickshell scales
            // tray pixmaps to the requested size, ignoring aspect), so the wide
            // pill uses a plain Image that requests its true 170x27 shape.
            Image {
                visible: slot.wide
                anchors.fill: parent
                source: slot.wide ? slot.modelData.icon : ""
                sourceSize: Qt.size(170, 27)
                smooth: true
                cache: false
                opacity: slot.containsMouse ? 1 : 0.95
            }

            onClicked: event => {
                if (justDragged) { justDragged = false; return }   // a drop isn't a click
                const item = slot.modelData
                if (event.button === Qt.LeftButton) {
                    if (item.onlyMenu && item.hasMenu) menu.toggle(item, slot)
                    else item.activate()
                } else if (event.button === Qt.RightButton) {
                    if (item.hasMenu) menu.toggle(item, slot)
                } else {
                    item.secondaryActivate()
                }
            }
            WheelSteps { id: wheel }
            onWheel: event => { const n = wheel.steps(event); if (n) slot.modelData.scroll(n, false) }

            Tooltip {
                target: slot
                text: slot.dragging ? "" : (slot.modelData.tooltipTitle || slot.modelData.title || slot.modelData.id)
            }
        }
    }
}

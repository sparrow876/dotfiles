// Smooth line graph of recent values (oldest first): a Catmull-Rom curve with
// a soft glow, a gradient fill and a dot on the newest value. values are scaled
// by `max` (0..max -> bottom..top). Up to two series: `values` (color) and
// optional `values2` (color2), e.g. download/upload. New points enter on the
// right; until the history is full the left part shows a dotted baseline.
import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: g
    property var values: []
    property var values2: []
    property real max: 1
    property int capacity: 40                 // points across the full width
    property color color: Theme.lightBlue
    property color color2: Theme.ice
    implicitHeight: 60

    function points(vals) {
        const pts = []
        const n = vals.length
        if (n === 0 || width <= 0) return pts
        const step = width / Math.max(1, capacity - 1)
        const x0 = width - (n - 1) * step
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(1, vals[i] / Math.max(1e-9, max)))
            pts.push({ x: x0 + i * step, y: height - 2 - v * (height - 6) })
        }
        return pts
    }
    // Catmull-Rom through the points as cubic Béziers (SVG path), clamped so
    // the curve never dips below the baseline or above the top
    function curve(pts) {
        if (pts.length === 0) return ""
        if (pts.length === 1) return `M ${pts[0].x} ${pts[0].y}`
        const cy = y => Math.max(1, Math.min(height - 1, y))
        let d = `M ${pts[0].x} ${pts[0].y}`
        for (let i = 0; i < pts.length - 1; i++) {
            const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(pts.length - 1, i + 2)]
            d += ` C ${p1.x + (p2.x - p0.x) / 6} ${cy(p1.y + (p2.y - p0.y) / 6)}` +
                 ` ${p2.x - (p3.x - p1.x) / 6} ${cy(p2.y - (p3.y - p1.y) / 6)} ${p2.x} ${p2.y}`
        }
        return d
    }
    function area(pts) {
        return pts.length > 1 ? curve(pts) + ` L ${pts[pts.length - 1].x} ${height} L ${pts[0].x} ${height} Z` : ""
    }
    readonly property var pts1: points(values)
    readonly property var pts2: points(values2)

    // faint grid lines + dotted baseline where there's no history yet
    Repeater {
        model: 3
        Rectangle {
            required property int index
            width: g.width; height: 1; y: Math.round(g.height * (index + 1) / 4)
            color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.05)
        }
    }
    Row {
        y: g.height - 2
        spacing: 4
        Repeater {
            model: g.pts1.length ? Math.max(0, Math.floor((g.pts1[0].x - 6) / 7)) : Math.floor(g.width / 7)
            Rectangle { width: 3; height: 1; color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.18) }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"; strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: g.height
                GradientStop { position: 0; color: Qt.rgba(g.color.r, g.color.g, g.color.b, 0.34) }
                GradientStop { position: 1; color: Qt.rgba(g.color.r, g.color.g, g.color.b, 0.0) }
            }
            PathSvg { path: g.area(g.pts1) }
        }
        ShapePath {   // glow
            strokeColor: Qt.rgba(g.color.r, g.color.g, g.color.b, 0.18); strokeWidth: 5; fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
            PathSvg { path: g.curve(g.pts1) }
        }
        ShapePath {
            strokeColor: g.color; strokeWidth: 1.8; fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
            PathSvg { path: g.curve(g.pts1) }
        }
        ShapePath {
            strokeColor: g.pts2.length ? Qt.rgba(g.color2.r, g.color2.g, g.color2.b, 0.16) : "transparent"
            strokeWidth: 5; fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
            PathSvg { path: g.curve(g.pts2) }
        }
        ShapePath {
            strokeColor: g.pts2.length ? g.color2 : "transparent"; strokeWidth: 1.5; fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
            PathSvg { path: g.curve(g.pts2) }
        }
    }

    // dot on the newest value (+ halo)
    component Dot: Item {
        property var pt: null
        property color tint
        visible: pt !== null
        x: (pt?.x ?? 0) - 6; y: (pt?.y ?? 0) - 6
        width: 12; height: 12
        Rectangle { anchors.fill: parent; radius: 6; color: Qt.rgba(parent.tint.r, parent.tint.g, parent.tint.b, 0.22) }
        Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: parent.tint }
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
    }
    Dot { pt: g.pts1.length ? g.pts1[g.pts1.length - 1] : null; tint: g.color }
    Dot { pt: g.pts2.length ? g.pts2[g.pts2.length - 1] : null; tint: g.color2 }
}

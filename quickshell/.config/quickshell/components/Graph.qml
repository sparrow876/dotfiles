// Line graph of recent values (oldest first) with a soft gradient fill.
// values are scaled by `max` (0..max -> bottom..top). Up to two series:
// `values` (light blue) and optional `values2` (ice), e.g. download/upload.
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
    implicitHeight: 54

    function line(vals) {
        const pts = []
        const n = vals.length
        if (n === 0) return pts
        const step = width / Math.max(1, capacity - 1)
        const x0 = width - (n - 1) * step
        for (let i = 0; i < n; i++) {
            const v = Math.max(0, Math.min(1, vals[i] / Math.max(1e-9, max)))
            pts.push(Qt.point(x0 + i * step, height - 1 - v * (height - 3)))
        }
        return pts
    }
    function area(pts) {
        return pts.length ? pts.concat([Qt.point(pts[pts.length - 1].x, height), Qt.point(pts[0].x, height)]) : []
    }
    readonly property var pts1: width > 0 ? line(values) : []
    readonly property var pts2: width > 0 ? line(values2) : []

    // faint grid line in the middle
    Rectangle { width: parent.width; height: 1; y: parent.height / 2; color: Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.06) }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"; strokeWidth: 0
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: g.height
                GradientStop { position: 0; color: Qt.rgba(g.color.r, g.color.g, g.color.b, 0.32) }
                GradientStop { position: 1; color: Qt.rgba(g.color.r, g.color.g, g.color.b, 0.0) }
            }
            PathPolyline { path: g.area(g.pts1) }
        }
        ShapePath {
            strokeColor: g.color; strokeWidth: 1.6; fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: g.pts1 }
        }
        ShapePath {
            strokeColor: g.pts2.length ? g.color2 : "transparent"; strokeWidth: 1.4; fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: g.pts2 }
        }
    }
}

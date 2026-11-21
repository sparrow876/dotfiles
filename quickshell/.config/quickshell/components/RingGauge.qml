// Circular gauge (0..1) with the value in the middle: a 270° arc with a soft
// glow. The arc is a gradient from color2 to color (pass the same color twice,
// e.g. a warning tone, for a solid arc). Optional tick marks; with `alert`
// the glow pulses (only while `live`, so a hidden panel costs nothing).
// The number in the middle follows the animated arc, so it counts up/down.
import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: ring
    property real value: 0
    property color color: Theme.lightBlue
    property color color2: Theme.blue
    property string sublabel: ""
    property real thickness: 8
    property int labelSize: Theme.fontSize + 5
    property bool ticks: false
    property bool alert: false
    property bool live: true
    // default label: the animated value as a percentage
    property string label: Math.round((sweep - 0.5) / 269.5 * 100) + "%"
    implicitWidth: 96
    implicitHeight: 96

    readonly property real r: width / 2 - thickness - (ticks ? 4 : 0)
    property real sweep: Math.max(0.5, 270 * Math.min(1, Math.max(0, value)))
    Behavior on sweep { NumberAnimation { duration: 420; easing.type: Easing.OutQuint } }

    // tick marks just outside the arc (every 10%)
    Repeater {
        model: ring.ticks ? 11 : 0
        Rectangle {
            required property int index
            readonly property real a: (135 + index * 27) * Math.PI / 180
            readonly property real rr: ring.r + ring.thickness / 2 + 4
            readonly property bool passed: index * 27 <= ring.sweep
            width: 2; height: 2; radius: 1
            x: ring.width / 2 + Math.cos(a) * rr - 1
            y: ring.height / 2 + Math.sin(a) * rr - 1
            color: passed ? Qt.rgba(ring.color.r, ring.color.g, ring.color.b, 0.9) : Qt.rgba(Theme.ice.r, Theme.ice.g, Theme.ice.b, 0.18)
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // track
        ShapePath {
            strokeColor: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.9)
            strokeWidth: ring.thickness; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: 135; sweepAngle: 270 }
        }
        // glow under the value arc (pulses on alert)
        ShapePath {
            id: glow
            property real strength: 0.16
            strokeColor: Qt.rgba(ring.color.r, ring.color.g, ring.color.b, strength)
            strokeWidth: ring.thickness + 7; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: 135; sweepAngle: ring.sweep }
        }
        // value arc: gradient from the bottom-left start to the top-right
        ShapePath {
            strokeWidth: ring.thickness; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            strokeGradient: LinearGradient {
                x1: 0; y1: ring.height; x2: ring.width; y2: 0
                GradientStop { position: 0; color: ring.color2 }
                GradientStop { position: 1; color: ring.color }
            }
            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.r; radiusY: ring.r; startAngle: 135; sweepAngle: ring.sweep }
        }
    }
    SequentialAnimation {
        running: ring.alert && ring.live
        loops: Animation.Infinite
        onStopped: glow.strength = 0.16
        NumberAnimation { target: glow; property: "strength"; to: 0.42; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { target: glow; property: "strength"; to: 0.12; duration: 700; easing.type: Easing.InOutSine }
    }

    Column {
        anchors.centerIn: parent
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.label
            font.pixelSize: ring.labelSize
            font.weight: Font.Bold
        }
        StyledText {
            visible: ring.sublabel !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.sublabel
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall - 1
        }
    }
}

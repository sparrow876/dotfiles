// Circular gauge (0..1) with the value in the middle: a 270° arc with a soft
// glow. The arc is a gradient from color2 to color (pass the same color twice,
// e.g. a warning tone, for a solid arc).
import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: ring
    property real value: 0
    property color color: Theme.lightBlue
    property color color2: Theme.blue
    property string label: Math.round(value * 100) + "%"
    property string sublabel: ""
    property real thickness: 8
    property int labelSize: Theme.fontSize + 5
    implicitWidth: 96
    implicitHeight: 96

    readonly property real r: width / 2 - thickness
    property real sweep: Math.max(0.5, 270 * Math.min(1, Math.max(0, value)))
    Behavior on sweep { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

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
        // glow under the value arc
        ShapePath {
            strokeColor: Qt.rgba(ring.color.r, ring.color.g, ring.color.b, 0.16)
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

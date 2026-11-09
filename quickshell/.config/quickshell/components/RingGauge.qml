// Circular gauge (0..1) with the value in the middle.
import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: ring
    property real value: 0
    property color color: Theme.lightBlue
    property string label: Math.round(value * 100) + "%"
    property string sublabel: ""
    property real thickness: 8
    implicitWidth: 96
    implicitHeight: 96

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.overlay; strokeWidth: ring.thickness; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.thickness; radiusY: radiusX
                startAngle: 135; sweepAngle: 270
            }
        }
        ShapePath {
            strokeColor: ring.color; strokeWidth: ring.thickness; fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.thickness; radiusY: radiusX
                startAngle: 135; sweepAngle: Math.max(0.5, 270 * Math.min(1, ring.value))
                Behavior on sweepAngle { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
            }
        }
    }
    Column {
        anchors.centerIn: parent
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.label
            font.pixelSize: Theme.fontSize + 5
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

import QtQuick
import QtQuick.Shapes

Item {
    id: spinner
    property bool running: visible
    property color color: Theme.accent
    implicitWidth: 18
    implicitHeight: 18

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        RotationAnimator on rotation {
            running: spinner.running
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
        ShapePath {
            strokeColor: spinner.color
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: spinner.width / 2
                centerY: spinner.height / 2
                radiusX: spinner.width / 2 - 1.5
                radiusY: spinner.height / 2 - 1.5
                startAngle: 0
                sweepAngle: 270
            }
        }
    }
}

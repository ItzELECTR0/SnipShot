import QtQuick
import QtQuick.Effects

Item {
    id: surface
    property alias color: panel.color
    property alias radius: panel.radius
    property bool elevated: true
    default property alias content: panel.data

    RectangularShadow {
        anchors.fill: panel
        visible: surface.elevated
        radius: panel.radius
        blur: 24
        spread: 0
        offset.y: 6
        color: Theme.shadow
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: Theme.flyout
        radius: Theme.radius
        border.width: 1
        border.color: Theme.stroke
    }
}

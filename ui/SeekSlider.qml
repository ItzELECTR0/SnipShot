import QtQuick
import QtQuick.Controls.Basic

Slider {
    id: slider
    implicitHeight: 24

    background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: slider.availableWidth
        height: 4
        radius: 2
        color: Theme.containerHighest
        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: Theme.accent
        }
    }
    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: slider.pressed || slider.hovered ? 14 : 12
        height: width
        radius: width / 2
        color: Theme.accent
        border.width: 2
        border.color: Theme.surface
    }
}

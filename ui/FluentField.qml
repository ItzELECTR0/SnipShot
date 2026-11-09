import QtQuick
import QtQuick.Controls

TextField {
    id: field
    implicitHeight: 32
    leftPadding: 10
    rightPadding: 10
    color: Theme.text
    placeholderTextColor: Theme.textSecondary
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentText
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    background: Rectangle {
        radius: Theme.controlRadius
        color: field.activeFocus ? Theme.surface : field.hovered ? Theme.controlHover : Theme.control
        border.color: Theme.stroke
        opacity: field.enabled ? 1 : 0.5
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            height: field.activeFocus ? 2 : 1
            radius: Theme.controlRadius
            color: field.activeFocus ? Theme.accent : Theme.textSecondary
            opacity: field.activeFocus ? 1 : 0.6
        }
    }
}

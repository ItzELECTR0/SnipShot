import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: field
    implicitHeight: Theme.controlHeight
    leftPadding: 10
    rightPadding: 10
    color: Theme.text
    placeholderTextColor: Theme.textMuted
    selectionColor: Theme.selection
    selectedTextColor: Theme.text
    selectByMouse: true
    font.family: Theme.fontFamily
    font.pixelSize: Theme.textSize
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        radius: Theme.controlRadius
        color: Theme.containerLow
        border.width: 1
        border.color: field.activeFocus ? Theme.accent : field.hovered ? Theme.outline : Theme.outlineVariant
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }
}

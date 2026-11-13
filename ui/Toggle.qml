import QtQuick
import QtQuick.Controls.Basic

Switch {
    id: control
    padding: 0
    spacing: 0
    implicitWidth: 38
    implicitHeight: 22
    opacity: enabled ? 1 : 0.4

    indicator: Rectangle {
        implicitWidth: 38
        implicitHeight: 22
        x: control.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        color: control.checked ? Theme.accent : Theme.containerHigh
        border.width: control.checked ? 0 : 1
        border.color: control.visualFocus ? Theme.accent : Theme.outline
        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            readonly property int size: control.checked || control.pressed ? 16 : 12
            width: control.pressed ? size + 3 : size
            height: size
            radius: size / 2
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? parent.width - width - 3 : (parent.height - height) / 2 + 1
            color: control.checked ? Theme.onAccent : Theme.textMuted
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 100 } }
        }
    }
    contentItem: Item {}
}

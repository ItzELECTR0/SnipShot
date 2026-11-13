import QtQuick
import QtQuick.Controls.Basic

// Fill with Action items; MenuDivider separates groups.
Menu {
    id: menu
    padding: 4
    implicitWidth: 200

    delegate: MenuItem {
        id: item
        implicitHeight: 30
        leftPadding: 10
        rightPadding: 10
        opacity: enabled ? 1 : 0.4
        contentItem: Text {
            text: item.text
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSize
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.radiusSmall
            color: item.pressed ? Theme.pressed : item.highlighted ? Theme.hover : "transparent"
        }
    }
    background: Rectangle {
        implicitWidth: menu.implicitWidth
        radius: Theme.controlRadius
        color: Theme.containerLow
        border.width: 1
        border.color: Theme.outlineVariant
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 } }
}

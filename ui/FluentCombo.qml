import QtQuick
import QtQuick.Controls

ComboBox {
    id: combo
    property var current
    implicitHeight: 32
    textRole: "label"
    valueRole: "value"
    currentIndex: {
        const items = model || []
        for (let index = 0; index < items.length; ++index)
            if (items[index].value === current) return index
        return 0
    }
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    leftPadding: 11
    rightPadding: 32
    contentItem: Text {
        text: combo.displayText
        color: Theme.text
        font: combo.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: FluentIcon {
        x: combo.width - width - 10
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron_down_regular"
        size: 12
        color: Theme.textSecondary
    }
    background: Rectangle {
        radius: Theme.controlRadius
        color: combo.pressed ? Theme.controlPressed : combo.hovered ? Theme.controlHover : Theme.control
        border.color: Theme.stroke
        opacity: combo.enabled ? 1 : 0.5
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            height: 1
            color: Theme.strokeStrong
        }
    }
}

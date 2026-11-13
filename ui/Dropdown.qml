import QtQuick
import QtQuick.Controls.Basic

// Model entries are {value, label}; `current` selects by value.
ComboBox {
    id: combo
    property var current
    implicitHeight: Theme.controlHeight
    textRole: "label"
    valueRole: "value"
    currentIndex: {
        const items = model || []
        for (let index = 0; index < items.length; ++index)
            if (items[index].value === current) return index
        return 0
    }
    font.family: Theme.fontFamily
    font.pixelSize: Theme.textSize
    leftPadding: 11
    rightPadding: 30
    opacity: enabled ? 1 : 0.4

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
        color: Theme.textMuted
    }
    background: Rectangle {
        radius: Theme.controlRadius
        color: combo.pressed ? Theme.pressed : combo.hovered ? Theme.container : Theme.containerLow
        border.width: 1
        border.color: combo.visualFocus || combo.popup.visible ? Theme.accent : Theme.outlineVariant
    }

    delegate: ItemDelegate {
        id: entry
        required property var modelData
        required property int index
        width: ListView.view ? ListView.view.width : implicitWidth
        implicitHeight: 30
        leftPadding: 10
        highlighted: combo.highlightedIndex === index
        contentItem: Text {
            text: entry.modelData.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSize
            font.weight: combo.currentIndex === entry.index ? Font.DemiBold : Font.Normal
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: Theme.radiusSmall
            color: entry.pressed ? Theme.pressed : entry.highlighted || entry.hovered ? Theme.hover : "transparent"
            Rectangle {
                visible: combo.currentIndex === entry.index
                x: 3
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 14
                radius: 1.5
                color: Theme.accent
            }
        }
    }

    popup: Popup {
        popupType: Popup.Window
        y: combo.height + 4
        width: combo.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 320)
        padding: 4
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: combo.popup.visible ? combo.delegateModel : null
            currentIndex: combo.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Scroller {}
        }
        background: Rectangle {
            radius: Theme.controlRadius
            color: Theme.containerLow
            border.width: 1
            border.color: Theme.outlineVariant
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 } }
    }
}

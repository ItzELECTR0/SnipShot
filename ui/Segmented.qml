import QtQuick

// Options are {value, label?, icon?, tooltip?}; set iconOnly to drop labels that have an icon.
Rectangle {
    id: root
    property var options: []
    property var current
    property bool iconOnly: false
    signal picked(var value)

    readonly property int currentIndex: {
        for (let index = 0; index < options.length; ++index)
            if (options[index].value === current) return index
        return -1
    }

    implicitWidth: row.implicitWidth + 6
    implicitHeight: Theme.controlHeight
    radius: Theme.controlRadius
    color: Theme.containerLow
    border.width: 1
    border.color: Theme.outlineVariant
    opacity: enabled ? 1 : 0.4
    Accessible.role: Accessible.PageTabList

    Rectangle {
        readonly property Item target: root.currentIndex >= 0 && repeater.count > root.currentIndex ? repeater.itemAt(root.currentIndex) : null
        visible: target !== null
        x: target ? target.x + row.x : 0
        y: 3
        width: target ? target.width : 0
        height: parent.height - 6
        radius: Theme.radiusSmall
        color: Theme.containerHighest
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            width: 14
            height: 2
            radius: 1
            color: Theme.accent
        }
    }

    Row {
        id: row
        x: 3
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            id: repeater
            model: root.options

            delegate: Item {
                id: segment
                required property var modelData
                required property int index
                readonly property bool chosen: root.currentIndex === index
                readonly property bool showLabel: !!modelData.label && !(root.iconOnly && modelData.icon)
                width: content.implicitWidth + (showLabel ? 22 : 16)
                height: root.height - 6
                Accessible.role: Accessible.PageTab
                Accessible.name: modelData.tooltip || modelData.label || ""
                Accessible.checked: chosen
                Accessible.onPressAction: root.picked(modelData.value)

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    color: mouse.containsMouse && !segment.chosen ? Theme.hover : "transparent"
                }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6
                    FluentIcon {
                        visible: !!segment.modelData.icon
                        anchors.verticalCenter: parent.verticalCenter
                        name: segment.modelData.icon || ""
                        color: segment.chosen ? Theme.text : Theme.textMuted
                    }
                    Text {
                        visible: segment.showLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: segment.modelData.label || ""
                        color: segment.chosen ? Theme.text : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSize - 1
                        font.weight: segment.chosen ? Font.DemiBold : Font.Normal
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.picked(segment.modelData.value)
                }

                Tip {
                    visible: mouse.containsMouse && !!segment.modelData.tooltip
                    text: segment.modelData.tooltip || ""
                }
            }
        }
    }
}

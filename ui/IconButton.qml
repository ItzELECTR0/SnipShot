import QtQuick
import QtQuick.Controls

Item {
    id: button
    property string icon
    property string text
    property string tooltip
    property string variant: "subtle"
    property bool checked: false
    property color iconColor: variant === "accent" ? Theme.accentText : checked ? Theme.accent : Theme.text
    property int iconSize: 16
    signal clicked()

    implicitWidth: text.length > 0 ? row.implicitWidth + 24 : 36
    implicitHeight: 36
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: tooltip.length > 0 ? tooltip : text
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()

    Rectangle {
        anchors.fill: parent
        radius: Theme.controlRadius
        color: {
            if (button.variant === "accent")
                return mouse.pressed ? Qt.darker(Theme.accent, 1.1) : mouse.containsMouse ? Theme.accentHover : Theme.accent
            if (button.variant === "standard")
                return mouse.pressed ? Theme.controlPressed : mouse.containsMouse ? Theme.controlHover : Theme.control
            if (mouse.pressed) return Theme.subtlePressed
            if (button.checked) return Theme.selected
            return mouse.containsMouse ? Theme.subtleHover : "transparent"
        }
        border.width: button.variant === "standard" || button.activeFocus ? 1 : 0
        border.color: button.activeFocus ? Theme.text : Theme.stroke
    }

    Rectangle {
        visible: button.checked && button.variant === "subtle"
        width: 14
        height: 3
        radius: 1.5
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.accent
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        FluentIcon {
            visible: button.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            name: button.icon
            size: button.iconSize
            color: button.iconColor
        }
        Text {
            visible: button.text.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: button.text
            color: button.variant === "accent" ? Theme.accentText : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        onClicked: button.clicked()
    }

    ToolTip.visible: mouse.containsMouse && tooltip.length > 0
    ToolTip.text: tooltip
    ToolTip.delay: 600
}

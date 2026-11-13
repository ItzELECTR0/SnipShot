import QtQuick

Item {
    id: button
    property string icon
    property string text
    property string tooltip
    // subtle: flat until hovered; standard: outlined; accent: filled with the accent colour.
    property string variant: "subtle"
    property bool checked: false
    property color iconColor: variant === "accent" ? Theme.onAccent : Theme.text
    property int iconSize: 16
    signal clicked()

    implicitWidth: text.length > 0 ? row.implicitWidth + 24 : Theme.controlHeight
    implicitHeight: Theme.controlHeight
    opacity: enabled ? 1 : 0.4
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
                return mouse.pressed ? Qt.darker(Theme.accent, 1.15) : mouse.containsMouse ? Qt.lighter(Theme.accent, Theme.dark ? 0.92 : 1.15) : Theme.accent
            if (mouse.pressed) return Theme.pressed
            if (button.checked) return Theme.containerHighest
            if (mouse.containsMouse) return Theme.hover
            return button.variant === "standard" ? Theme.containerLow : "transparent"
        }
        border.width: button.variant === "standard" || button.activeFocus ? 1 : 0
        border.color: button.activeFocus ? Theme.accent : Theme.outlineVariant
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
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
            color: button.variant === "accent" ? Theme.onAccent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSize
            font.weight: button.variant === "accent" ? Font.DemiBold : Font.Normal
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        onClicked: button.clicked()
    }

    Tip {
        visible: mouse.containsMouse && button.tooltip.length > 0
        text: button.tooltip
    }
}

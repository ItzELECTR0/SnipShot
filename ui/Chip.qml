import QtQuick

// A selectable pill used for theme names and OCR languages.
Rectangle {
    id: chip
    property string text
    property bool checked: false
    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 30
    radius: Theme.controlRadius
    color: checked ? Theme.containerHighest : mouse.containsMouse ? Theme.hover : Theme.containerLow
    border.width: 1
    border.color: checked ? Qt.alpha(Theme.accent, 0.7) : Theme.outlineVariant
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.checkable: true
    Accessible.name: text
    Accessible.checked: checked
    Accessible.onPressAction: clicked()
    Keys.onSpacePressed: clicked()

    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.checked ? Theme.text : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSize - 1
        font.weight: chip.checked ? Font.DemiBold : Font.Normal
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: chip.clicked()
    }
}

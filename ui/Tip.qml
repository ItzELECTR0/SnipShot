import QtQuick
import QtQuick.Controls.Basic

ToolTip {
    id: tip
    delay: 600
    padding: 0
    leftPadding: 9
    rightPadding: 9
    topPadding: 5
    bottomPadding: 5
    y: parent ? parent.height + 6 : 0
    x: parent ? (parent.width - implicitWidth) / 2 : 0

    contentItem: Text {
        text: tip.text
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.smallSize + 1
    }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.containerHigh
        border.width: 1
        border.color: Theme.outlineVariant
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 100 } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 } }
}

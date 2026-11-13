import QtQuick
import SnipShot.Core

Window {
    id: window
    visible: Capture.pillVisible
    width: pill.implicitWidth + 32
    height: pill.implicitHeight + 32
    color: "transparent"
    title: "SnipShot status"
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus

    Surface {
        id: pill
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + 32
        implicitHeight: 44
        width: implicitWidth
        height: implicitHeight
        radius: height / 2

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10
            Spinner {
                visible: Capture.pillBusy
                anchors.verticalCenter: parent.verticalCenter
            }
            FluentIcon {
                visible: !Capture.pillBusy && Capture.pillIcon.length > 0
                anchors.verticalCenter: parent.verticalCenter
                name: Capture.pillIcon
                color: Capture.pillIcon === "dismiss_regular" ? Theme.record : Theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Capture.pillText
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSize
                width: Math.min(implicitWidth, 560)
                elide: Text.ElideRight
            }
        }
    }
}

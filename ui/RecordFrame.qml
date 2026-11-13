import QtQuick
import SnipShot.Core

Window {
    id: frame
    readonly property string phase: Capture.state
    visible: phase === "countdown" || phase === "starting" || phase === "recording" || phase === "finishing"
    color: "transparent"
    title: "SnipShot recording frame"
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 3
        border.color: Capture.paused ? Theme.textMuted : Theme.record
    }

    Rectangle {
        visible: frame.phase === "countdown"
        anchors.centerIn: parent
        width: Math.min(120, Math.min(frame.width, frame.height) - 24)
        height: width
        radius: width / 2
        color: "#99000000"
        Text {
            anchors.centerIn: parent
            text: Capture.countdown
            color: "#ffffff"
            font.family: Theme.fontFamily
            font.pixelSize: parent.width * 0.5
            font.weight: Font.DemiBold
        }
    }
}

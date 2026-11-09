import QtQuick
import SnipShot.Core

Window {
    readonly property string phase: Capture.state
    visible: phase === "countdown" || phase === "starting" || phase === "recording" || phase === "finishing"
    width: controls.implicitWidth + 32
    height: controls.implicitHeight + 32
    color: "transparent"
    title: "SnipShot recording"
    flags: Qt.FramelessWindowHint

    RecordControls {
        id: controls
        anchors.centerIn: parent
    }
}

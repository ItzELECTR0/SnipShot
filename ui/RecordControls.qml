import QtQuick
import SnipShot.Core

Surface {
    id: bar
    readonly property string phase: Capture.state
    readonly property bool armed: phase === "armed"
    readonly property bool running: phase === "recording"
    readonly property bool waiting: phase === "countdown" || phase === "starting" || phase === "finishing"

    function clock(milliseconds) {
        const seconds = Math.floor(milliseconds / 1000)
        const hours = Math.floor(seconds / 3600)
        const pad = value => String(value).padStart(2, "0")
        return (hours > 0 ? hours + ":" : "") + pad(Math.floor(seconds / 60) % 60) + ":" + pad(seconds % 60)
    }

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 48
    width: implicitWidth
    height: implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        IconButton {
            visible: bar.armed
            variant: "accent"
            icon: "record_filled"
            text: qsTr("Start")
            tooltip: qsTr("Start recording (Enter)")
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Capture.startRecording()
        }

        Item {
            visible: !bar.armed
            width: status.implicitWidth + 20
            height: Theme.controlHeight
            Row {
                id: status
                anchors.centerIn: parent
                spacing: 8
                Rectangle {
                    visible: bar.running
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 5
                    color: Capture.paused ? Theme.textMuted : Theme.record
                    SequentialAnimation on opacity {
                        running: bar.running && !Capture.paused
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.opacity = 1
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
                Spinner {
                    visible: bar.waiting
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.phase === "countdown" ? qsTr("Starting in %1").arg(Capture.countdown)
                        : bar.phase === "starting" ? qsTr("Starting")
                        : bar.phase === "finishing" ? qsTr("Saving")
                        : bar.clock(Capture.elapsed)
                    color: Capture.paused && bar.running ? Theme.textMuted : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                    font.features: { "tnum": 1 }
                }
            }
        }

        IconButton {
            visible: bar.running
            icon: Capture.paused ? "play_filled" : "pause_filled"
            tooltip: Capture.paused ? qsTr("Resume") : qsTr("Pause")
            onClicked: Capture.togglePause()
        }
        IconButton {
            visible: bar.running
            icon: "stop_filled"
            iconColor: Theme.record
            tooltip: qsTr("Stop")
            onClicked: Capture.stopRecording()
        }
        IconButton {
            visible: bar.running
            icon: "delete_regular"
            tooltip: qsTr("Discard")
            onClicked: Capture.discardRecording()
        }

        Item { width: 6; height: 1 }
        Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.outlineVariant }
        Item { width: 6; height: 1 }

        IconButton {
            enabled: bar.armed
            icon: Capture.microphone ? "mic_regular" : "mic_off_regular"
            checked: Capture.microphone
            tooltip: Capture.microphone ? qsTr("Microphone on") : qsTr("Microphone off")
            onClicked: Capture.microphone = !Capture.microphone
        }
        IconButton {
            enabled: bar.armed
            icon: Capture.systemAudio ? "speaker_2_regular" : "speaker_off_regular"
            checked: Capture.systemAudio
            tooltip: Capture.systemAudio ? qsTr("System audio on") : qsTr("System audio off")
            onClicked: Capture.systemAudio = !Capture.systemAudio
        }
        IconButton {
            visible: bar.armed || bar.phase === "countdown"
            icon: "dismiss_regular"
            tooltip: qsTr("Cancel")
            onClicked: Capture.cancel()
        }
    }
}

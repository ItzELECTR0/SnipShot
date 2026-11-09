import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import SnipShot.Core

Item {
    id: preview

    function clock(milliseconds) {
        const seconds = Math.floor(milliseconds / 1000)
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0")
    }

    MediaPlayer {
        id: player
        property bool primed: false
        property bool priming: false
        source: Capture.resultUrl
        videoOutput: output
        audioOutput: AudioOutput { muted: player.priming }
        // Play silently until the first frame decodes so the preview is not a black box.
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia && !primed) {
            primed = true
            priming = true
            play()
        }
        onPositionChanged: if (priming && position > 0) {
            priming = false
            pause()
            position = 0
        }
    }

    function toggle() {
        if (player.priming) {
            player.priming = false
            return
        }
        player.playing ? player.pause() : player.play()
    }

    Shortcut {
        sequences: ["Space", "K"]
        onActivated: preview.toggle()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius
            color: "#000000"
            clip: true

            VideoOutput {
                id: output
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }
            MouseArea {
                anchors.fill: parent
                onClicked: preview.toggle()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                icon: player.playing && !player.priming ? "pause_filled" : "play_filled"
                tooltip: player.playing && !player.priming ? qsTr("Pause (Space)") : qsTr("Play (Space)")
                onClicked: preview.toggle()
            }
            Text {
                text: preview.clock(player.position)
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.captionSize
                font.features: { "tnum": 1 }
            }
            Slider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, player.duration)
                value: player.position
                onMoved: player.position = value
            }
            Text {
                text: preview.clock(player.duration)
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.captionSize
                font.features: { "tnum": 1 }
            }
        }
    }

    Component.onDestruction: player.stop()
}

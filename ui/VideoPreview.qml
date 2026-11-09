import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Item {
    id: preview
    property url sourceUrl: capture.resultUrl

    MediaPlayer {
        id: player
        source: preview.sourceUrl
        videoOutput: output
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: "#080d13"
            clip: true

            VideoOutput {
                id: output
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                id: playbackButton
                implicitWidth: 44
                implicitHeight: 44
                Accessible.name: player.playing ? "Pause playback" : "Play playback"
                ToolTip.visible: hovered
                ToolTip.text: player.playing ? "Pause playback" : "Play playback"
                ToolTip.delay: 450
                background: Rectangle {
                    radius: 10
                    color: playbackButton.down ? "#465464"
                        : playbackButton.hovered ? "#303c4a" : "#26313e"
                    border.color: playbackButton.activeFocus ? "#8bd9b8" : "#526071"
                }
                contentItem: Item {
                    Canvas {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        visible: !player.playing
                        onVisibleChanged: if (visible) requestPaint()
                        onPaint: {
                            const context = getContext("2d")
                            context.clearRect(0, 0, width, height)
                            context.fillStyle = "#e4ebf2"
                            context.beginPath()
                            context.moveTo(4, 2)
                            context.lineTo(18, 10)
                            context.lineTo(4, 18)
                            context.closePath()
                            context.fill()
                        }
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        visible: player.playing
                        Rectangle { width: 5; height: 18; radius: 1; color: "#e4ebf2" }
                        Rectangle { width: 5; height: 18; radius: 1; color: "#e4ebf2" }
                    }
                }
                onClicked: player.playing ? player.pause() : player.play()
            }

            Slider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, player.duration)
                value: player.position
                onMoved: player.position = value
            }

            Text {
                text: `${Math.floor(player.position / 60000)}:${String(Math.floor(player.position / 1000) % 60).padStart(2, "0")}`
                color: "#aeb8c7"
                font.pixelSize: 12
            }
        }
    }

    Component.onDestruction: player.stop()
}

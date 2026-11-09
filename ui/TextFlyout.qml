import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SnipShot.Core

Window {
    id: window
    visible: Capture.textOpen
    width: 452
    height: 332
    color: "transparent"
    title: "SnipShot text"
    flags: Qt.FramelessWindowHint

    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: Capture.closeText()
    }

    Surface {
        anchors.fill: parent
        anchors.margins: 16

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                FluentIcon { name: "scan_text_regular"; color: Theme.accent }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    text: qsTr("Extracted text")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                }
                IconButton {
                    icon: "copy_regular"
                    tooltip: qsTr("Copy all text")
                    onClicked: Capture.copyText()
                }
                IconButton {
                    icon: "dismiss_regular"
                    tooltip: qsTr("Close")
                    onClicked: Capture.closeText()
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                TextArea {
                    text: Capture.recognizedText
                    readOnly: true
                    verticalAlignment: TextEdit.AlignTop
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    background: Rectangle {
                        radius: Theme.controlRadius
                        color: Theme.surface
                        border.color: Theme.stroke
                    }
                }
            }
        }
    }
}

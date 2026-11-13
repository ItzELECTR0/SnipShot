import QtQuick
import QtQuick.Controls.Basic
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
                    font.pixelSize: Theme.textSize
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
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                ScrollBar.vertical: Scroller { parent: scroll; x: scroll.width - width; y: 2; height: scroll.height - 4 }
                TextArea {
                    text: Capture.recognizedText
                    readOnly: true
                    verticalAlignment: TextEdit.AlignTop
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    selectionColor: Theme.selection
                    selectedTextColor: Theme.text
                    padding: 10
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSize
                    background: Rectangle {
                        radius: Theme.controlRadius
                        color: Theme.containerLow
                        border.color: Theme.outlineVariant
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts

Window {
    id: window
    objectName: "toolbar"
    visible: false
    width: capture.recording ? 434 : Screen.width
    height: capture.recording ? 68 : Screen.height
    flags: Qt.Tool | Qt.FramelessWindowHint
    color: "transparent"
    title: "SnipShot"

    function dismissMenu() {
        if (!capture.recording) window.visible = false
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: window.dismissMenu()
    }

    property int recordingSeconds: 0

    Timer {
        interval: 1000
        repeat: true
        running: capture.recording && !capture.paused && !capture.busy
        onTriggered: window.recordingSeconds += 1
    }

    MouseArea {
        anchors.fill: parent
        enabled: !capture.recording
        onClicked: {}
    }

    Rectangle {
        width: capture.recording ? 434 : 184
        height: 68
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16
        radius: 19
        color: "#f016202b"
        border.color: "#526071"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 4

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: capture.recording ? (capture.paused ? "#e6b55b" : "#ed6f68")
                    : capture.busy ? "#e6b55b" : "#8bd9b8"
                Layout.leftMargin: 5
            }

            RowLayout {
                visible: capture.recording
                Layout.fillWidth: true
                spacing: 7
                Text {
                    text: `${String(Math.floor(window.recordingSeconds / 60)).padStart(2, "0")}:${String(window.recordingSeconds % 60).padStart(2, "0")}`
                    color: capture.paused ? "#e6b55b" : "#f0f3f7"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    font.family: "monospace"
                }
                Text {
                    Layout.fillWidth: true
                    text: capture.busy ? capture.status : capture.paused ? "Paused" : "Recording"
                    color: capture.paused ? "#e6b55b" : capture.busy ? "#e6b55b" : "#aeb8c7"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

    RowLayout {
        visible: !capture.recording
                Layout.fillWidth: true
                spacing: 4
                IconButton {
                    glyphKind: "capture"
                    tooltip: "Capture image"
                    accent: true
                    enabled: !capture.busy
                    onClicked: {
                        window.dismissMenu()
                        capture.captureImage()
                    }
                }
                IconButton {
                    glyphKind: "record"
                    tooltip: "Record region"
                    enabled: !capture.busy
                    onClicked: {
                        window.recordingSeconds = 0
                        window.dismissMenu()
                        capture.recordRegion()
                    }
                }
                IconButton {
                    glyphKind: "text"
                    tooltip: "Extract text"
                    enabled: !capture.busy
                    onClicked: {
                        window.dismissMenu()
                        capture.extractText()
                    }
                }
            }

            RowLayout {
                visible: capture.recording
                spacing: 2
                IconButton {
                    glyphKind: capture.paused ? "resume" : "pause"
                    tooltip: capture.paused ? "Resume recording" : "Pause recording"
                    enabled: !capture.busy
                    onClicked: capture.toggleRecordingPause()
                }
                IconButton {
                    glyphKind: "stop"
                    tooltip: "Stop recording"
                    stopStyle: true
                    enabled: !capture.busy
                    onClicked: capture.stopRecording()
                }
            }
        }
    }

    Window {
        id: textResult
        objectName: "textResultWindow"
        visible: false
        width: 360
        height: 250
        color: "transparent"
        flags: Qt.Tool | Qt.FramelessWindowHint
        title: "Extracted text"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 13
            color: "#f016202b"
            border.color: "#526071"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 9
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Extracted text"
                        color: "#f0f3f7"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    IconButton {
                        glyphKind: "copy"
                        tooltip: "Copy text"
                        enabled: capture.recognizedText.length > 0
                        onClicked: capture.copyText()
                    }
                    IconButton {
                        glyphKind: "close"
                        tooltip: "Close extracted text"
                        onClicked: textResult.visible = false
                    }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: Math.max(height, recognizedTextEdit.contentHeight)
                    TextEdit {
                        id: recognizedTextEdit
                        width: parent.width
                        text: capture.recognizedText || "No text found in that region."
                        color: "#dce3ed"
                        readOnly: true
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    Connections {
        target: capture
        function onRecognizedTextChanged() {
            textResult.visible = true
        }
    }

    Window {
        id: preview
        objectName: "previewWindow"
        visible: capture.previewOpen
        width: 960
        height: 640
        color: "#101720"
        flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
        transientParent: null
        title: capture.resultType === "image" ? "Screenshot preview" : "Recording preview"
        onClosing: capture.closePreview()

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: capture.resultType === "image" ? "Screenshot" : "Recording"
                    color: "#f0f3f7"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }
                IconButton {
                    glyphKind: "close"
                    tooltip: "Close preview"
                    onClicked: capture.closePreview()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: "#080d13"
                clip: true

                Image {
                    anchors.fill: parent
                    visible: capture.resultType === "image"
                    source: capture.resultType === "image" ? capture.resultUrl : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Loader {
                    anchors.fill: parent
                    visible: capture.resultType === "video"
                    active: capture.previewOpen && capture.resultType === "video"
                    source: active ? Qt.resolvedUrl("VideoPreview.qml") : ""
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ActionButton {
                    Layout.fillWidth: true
                    text: "Copy to Clipboard"
                    actionEnabled: !capture.busy
                    onClicked: capture.copyResult()
                }
                ActionButton {
                    Layout.fillWidth: true
                    text: "Save to File"
                    actionEnabled: !capture.busy
                    onClicked: capture.saveResult()
                }
            }
        }

    }

    Window {
        id: outline
        objectName: "recordingOutline"
        visible: capture.recording
        width: capture.recordingWidth + 6
        height: capture.recordingHeight + 6
        color: "transparent"
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
        title: "SnipShot recording region"

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 3
            border.color: capture.paused ? "#e6b55b" : "#ed6f68"
            radius: 4
        }
    }

    component ActionButton: Rectangle {
        id: action
        property string text: ""
        property bool actionEnabled: true
        signal clicked()
        Accessible.name: text
        Accessible.role: Accessible.Button
        activeFocusOnTab: actionEnabled
        Keys.onReturnPressed: if (actionEnabled) action.clicked()
        Keys.onSpacePressed: if (actionEnabled) action.clicked()
        implicitHeight: 42
        radius: 10
        color: !action.actionEnabled ? "#202a36"
            : actionMouse.pressed ? "#465464"
            : actionMouse.containsMouse ? "#303c4a" : "#26313e"
        border.color: action.activeFocus ? "#8bd9b8" : "#526071"

        Text {
            anchors.centerIn: parent
            text: action.text
            color: action.actionEnabled ? "#e4ebf2" : "#77818f"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            enabled: action.actionEnabled
            hoverEnabled: true
            onClicked: action.clicked()
        }
    }

    component IconButton: Item {
        id: control
        property string glyphKind: "capture"
        property string tooltip: ""
        property bool accent: false
        property bool stopStyle: false
        property bool hovered: mouse.containsMouse
        property bool down: mouse.pressed
        signal clicked()
        implicitWidth: 44
        implicitHeight: 44
        Accessible.name: tooltip
        Accessible.role: Accessible.Button
        activeFocusOnTab: true
        Keys.onReturnPressed: control.clicked()
        Keys.onSpacePressed: control.clicked()
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: control.down ? "#465464"
                : control.hovered ? (control.accent ? "#40566a" : "#303c4a")
                : "transparent"
            border.color: control.activeFocus ? "#8bd9b8" : "transparent"
            border.width: control.activeFocus ? 2 : 0
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: control.enabled
            onClicked: control.clicked()
        }
        Item {
            anchors.fill: parent
            Rectangle {
                visible: control.glyphKind === "capture"
                width: 21
                height: 16
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                radius: 4
                color: "transparent"
                border.width: 2
                border.color: control.enabled ? "#e4ebf2" : "#77818f"
                Rectangle {
                    width: 8
                    height: 4
                    x: 4
                    y: -4
                    radius: 2
                    color: parent.border.color
                }
                Rectangle {
                    width: 7
                    height: 7
                    x: 7
                    y: 3
                    radius: 4
                    color: "transparent"
                    border.width: 1.7
                    border.color: parent.border.color
                }
            }
            Rectangle {
                visible: control.glyphKind === "record"
                width: 16
                height: 16
                anchors.centerIn: parent
                radius: 9
                color: control.enabled ? "#ed6f68" : "#77818f"
            }
            Text {
                visible: control.glyphKind === "text"
                text: "T"
                anchors.centerIn: parent
                color: control.enabled ? "#e4ebf2" : "#77818f"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                font.family: "serif"
            }
            Row {
                visible: control.glyphKind === "pause"
                anchors.centerIn: parent
                spacing: 4
                Rectangle { width: 4; height: 16; radius: 1; color: "#e4ebf2" }
                Rectangle { width: 4; height: 16; radius: 1; color: "#e4ebf2" }
            }
            Text {
                visible: control.glyphKind === "resume"
                text: "▶"
                anchors.centerIn: parent
                color: "#e6b55b"
                font.pixelSize: 18
            }
            Text {
                visible: control.glyphKind === "close"
                text: "×"
                anchors.centerIn: parent
                color: control.enabled ? "#e4ebf2" : "#77818f"
                font.pixelSize: 24
            }
            Item {
                visible: control.glyphKind === "copy"
                anchors.fill: parent
                Rectangle {
                    x: 15
                    y: 12
                    width: 13
                    height: 16
                    radius: 2
                    color: "transparent"
                    border.width: 1.7
                    border.color: control.enabled ? "#e4ebf2" : "#77818f"
                }
                Rectangle {
                    x: 11
                    y: 16
                    width: 13
                    height: 16
                    radius: 2
                    color: "#202a36"
                    border.width: 1.7
                    border.color: control.enabled ? "#e4ebf2" : "#77818f"
                }
            }
            Rectangle {
                visible: control.glyphKind === "stop"
                width: 14
                height: 14
                anchors.centerIn: parent
                radius: 3
                color: control.enabled ? "#ed6f68" : "#77818f"
            }
        }
        Rectangle {
            visible: control.hovered && control.tooltip.length > 0
            width: tooltipText.implicitWidth + 16
            height: tooltipText.implicitHeight + 10
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            radius: 6
            color: "#f016202b"
            border.color: "#526071"
            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: control.tooltip
                color: "#f0f3f7"
                font.pixelSize: 12
            }
        }
    }
}

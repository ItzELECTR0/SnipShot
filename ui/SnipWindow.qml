import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import SnipShot.Core

Window {
    id: window
    readonly property bool image: Capture.resultType === "image"
    property bool actualSize: false

    visible: Capture.snipOpen
    title: "SnipShot Snip"
    color: Theme.surface
    minimumWidth: 560
    minimumHeight: 360
    readonly property int preferredWidth: Math.max(minimumWidth, Math.min(Capture.resultSize.width + 48, Screen.desktopAvailableWidth * 0.8))
    readonly property int preferredHeight: Math.max(minimumHeight, Math.min(Capture.resultSize.height + (image ? 140 : 190), Screen.desktopAvailableHeight * 0.8))
    width: preferredWidth
    height: preferredHeight
    onVisibleChanged: {
        actualSize = false
        if (visible) {
            width = preferredWidth
            height = preferredHeight
            Capture.floatWindow(title, preferredWidth, preferredHeight)
        }
    }
    onClosing: Capture.closeSnip()

    Shortcut { sequences: [StandardKey.Copy]; enabled: window.image; onActivated: Capture.copyResult() }
    Shortcut { sequences: [StandardKey.Save, StandardKey.SaveAs]; onActivated: Capture.saveResult() }
    Shortcut { sequences: ["Ctrl+N"]; onActivated: Capture.start(window.image ? "snip" : "record") }
    Shortcut { sequences: ["Ctrl+0"]; onActivated: window.actualSize = !window.actualSize }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 4

            IconButton {
                variant: "accent"
                icon: "add_regular"
                text: qsTr("New")
                tooltip: qsTr("New (Ctrl+N)")
                onClicked: Capture.start(window.image ? "snip" : "record")
            }
            Item { Layout.fillWidth: true }
            IconButton {
                visible: window.image
                icon: "zoom_fit_regular"
                checked: window.actualSize
                tooltip: window.actualSize ? qsTr("Fit to window (Ctrl+0)") : qsTr("Actual size (Ctrl+0)")
                onClicked: window.actualSize = !window.actualSize
            }
            IconButton {
                icon: "save_regular"
                tooltip: qsTr("Save as (Ctrl+S)")
                onClicked: Capture.saveResult()
            }
            IconButton {
                icon: "copy_regular"
                tooltip: window.image ? qsTr("Copy (Ctrl+C)") : qsTr("Copy file")
                onClicked: Capture.copyResult()
            }
            IconButton {
                icon: "folder_open_regular"
                enabled: Capture.resultSaved
                tooltip: qsTr("Show in folder")
                onClicked: Capture.openResultFolder()
            }
            IconButton {
                icon: "more_horizontal_regular"
                tooltip: menu.visible ? "" : qsTr("More")
                onClicked: menu.open()
                PopupMenu {
                    id: menu
                    x: parent.width - width
                    y: parent.height + 4
                    Action { text: qsTr("Open with default app"); onTriggered: Capture.openResultExternally() }
                    Action { text: qsTr("Settings"); onTriggered: Capture.showSettings() }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.containerLow

            Rectangle { width: parent.width; height: 1; color: Theme.outlineVariant; z: 1 }
            Rectangle { width: parent.width; height: 1; anchors.bottom: parent.bottom; color: Theme.outlineVariant; z: 1 }
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: window.actualSize ? 0 : 16
                visible: window.image
                contentWidth: window.actualSize ? Math.max(width, Capture.resultSize.width) : width
                contentHeight: window.actualSize ? Math.max(height, Capture.resultSize.height) : height
                interactive: window.actualSize
                ScrollBar.horizontal: Scroller { policy: window.actualSize ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                ScrollBar.vertical: Scroller { policy: window.actualSize ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

                Image {
                    readonly property real fitScale: Math.min(1, flick.width / Math.max(1, Capture.resultSize.width), flick.height / Math.max(1, Capture.resultSize.height))
                    width: window.actualSize ? Capture.resultSize.width : Capture.resultSize.width * fitScale
                    height: window.actualSize ? Capture.resultSize.height : Capture.resultSize.height * fitScale
                    x: (flick.contentWidth - width) / 2
                    y: (flick.contentHeight - height) / 2
                    source: window.image && window.visible ? Capture.resultUrl : ""
                    cache: false
                    smooth: true
                    mipmap: !window.actualSize
                    asynchronous: true
                }
            }

            Loader {
                anchors.fill: parent
                anchors.margins: 16
                active: window.visible && !window.image && Capture.resultPath.length > 0
                visible: active
                source: active ? Qt.resolvedUrl("VideoPreview.qml") : ""
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.topMargin: 6
            Layout.bottomMargin: 8
            Text {
                text: Capture.resultSize.width + " × " + Capture.resultSize.height + (window.image ? " px" : "")
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallSize
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: Capture.resultSaved ? Capture.resultPath : qsTr("Not saved yet")
                elide: Text.ElideMiddle
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallSize
            }
        }
    }
}

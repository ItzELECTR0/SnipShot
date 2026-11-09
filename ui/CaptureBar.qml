import QtQuick
import SnipShot.Core

Surface {
    id: bar
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 48
    width: implicitWidth
    height: implicitHeight

    component Divider: Rectangle {
        width: 1
        height: 20
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Theme.stroke
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        IconButton {
            icon: "camera_regular"
            tooltip: qsTr("Snip")
            checked: Capture.purpose !== "record"
            onClicked: if (Capture.purpose === "record") Capture.purpose = "snip"
        }
        IconButton {
            icon: "video_regular"
            tooltip: qsTr("Record")
            checked: Capture.purpose === "record"
            onClicked: Capture.purpose = "record"
        }
        Item { width: 6; height: 1 }
        Divider {}
        Item { width: 6; height: 1 }
        IconButton {
            icon: "rectangle_landscape_regular"
            tooltip: qsTr("Rectangle")
            checked: Capture.mode === "rectangle"
            onClicked: Capture.mode = "rectangle"
        }
        IconButton {
            visible: Capture.windowModeAvailable
            icon: "window_regular"
            tooltip: qsTr("Window")
            checked: Capture.mode === "window"
            onClicked: Capture.mode = "window"
        }
        IconButton {
            icon: "full_screen_maximize_regular"
            tooltip: qsTr("Full screen")
            checked: Capture.mode === "fullscreen"
            onClicked: Capture.mode = "fullscreen"
        }
        IconButton {
            visible: Capture.purpose !== "record"
            icon: "lasso_regular"
            tooltip: qsTr("Freeform")
            checked: Capture.mode === "freeform"
            onClicked: Capture.mode = "freeform"
        }
        Item { width: 6; height: 1; visible: Capture.purpose !== "record" }
        Divider { visible: Capture.purpose !== "record" }
        Item { width: 6; height: 1; visible: Capture.purpose !== "record" }
        IconButton {
            visible: Capture.purpose !== "record"
            icon: "scan_text_regular"
            tooltip: qsTr("Text extractor")
            checked: Capture.purpose === "text"
            onClicked: Capture.purpose = Capture.purpose === "text" ? "snip" : "text"
        }
        Item { width: 6; height: 1 }
        Divider {}
        Item { width: 6; height: 1 }
        IconButton {
            icon: "dismiss_regular"
            tooltip: qsTr("Close (Esc)")
            onClicked: Capture.cancel()
        }
    }
}

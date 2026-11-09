import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SnipShot.Core

Window {
    id: window
    property string purpose: "snip"

    visible: Capture.mainOpen
    title: "SnipShot"
    width: 600
    height: 168
    minimumWidth: 520
    minimumHeight: 150
    color: Theme.window
    onVisibleChanged: if (visible) Capture.floatWindow(title, 600, 168)
    onClosing: Capture.closeMain()

    readonly property var modes: [
        { value: "rectangle", label: qsTr("Rectangle"), icon: "rectangle_landscape_regular" },
        { value: "window", label: qsTr("Window"), icon: "window_regular" },
        { value: "fullscreen", label: qsTr("Full screen"), icon: "full_screen_maximize_regular" },
        { value: "freeform", label: qsTr("Freeform"), icon: "lasso_regular" }
    ]
    readonly property var delays: [0, 3, 5, 10]

    Shortcut {
        sequences: ["Ctrl+N"]
        onActivated: Capture.start(window.purpose)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                variant: "accent"
                icon: "add_regular"
                text: qsTr("New")
                tooltip: qsTr("New snip (Ctrl+N)")
                onClicked: Capture.start(window.purpose)
            }

            Rectangle {
                implicitWidth: toggles.implicitWidth + 4
                implicitHeight: 36
                radius: Theme.controlRadius
                color: Theme.control
                border.color: Theme.stroke
                Row {
                    id: toggles
                    anchors.centerIn: parent
                    IconButton {
                        icon: "camera_regular"
                        tooltip: qsTr("Snip")
                        implicitHeight: 32
                        checked: window.purpose === "snip"
                        onClicked: window.purpose = "snip"
                    }
                    IconButton {
                        icon: "video_regular"
                        tooltip: qsTr("Record")
                        implicitHeight: 32
                        checked: window.purpose === "record"
                        onClicked: {
                            window.purpose = "record"
                            if (Capture.mode === "freeform") Capture.mode = "rectangle"
                        }
                    }
                }
            }

            FluentCombo {
                id: modeBox
                Layout.preferredWidth: 160
                model: window.modes.filter(mode => !(window.purpose === "record" && mode.value === "freeform"))
                current: Capture.mode
                onActivated: Capture.mode = currentValue
                Accessible.name: qsTr("Snipping mode")
            }

            FluentCombo {
                Layout.preferredWidth: 140
                model: window.delays.map(seconds => ({ value: seconds, label: seconds === 0 ? qsTr("No delay") : qsTr("%1 seconds").arg(seconds) }))
                current: Config.delay
                onActivated: Config.delay = currentValue
                Accessible.name: qsTr("Delay")
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: "more_horizontal_regular"
                tooltip: qsTr("See more")
                onClicked: menu.popup(this, 0, height)
                Menu {
                    id: menu
                    MenuItem { text: qsTr("Settings"); onTriggered: Capture.showSettings() }
                    MenuItem { text: qsTr("Open last capture"); enabled: Capture.resultPath.length > 0; onTriggered: Capture.showSnip() }
                    MenuSeparator {}
                    MenuItem { text: qsTr("Quit SnipShot"); onTriggered: Capture.quit() }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: Capture.state === "idle" || Capture.status.length === 0
                ? (window.purpose === "record"
                    ? qsTr("Select New to record an area of your screen. Bind \"snipshot record\" to a key to start recording from anywhere.")
                    : qsTr("Select the snip mode or New to start. Bind \"snipshot snip\" to a key, like Super+Shift+S, to snip from anywhere."))
                : Capture.status
            wrapMode: Text.Wrap
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            verticalAlignment: Text.AlignVCenter
        }
    }
}

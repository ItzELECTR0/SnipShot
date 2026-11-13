import QtQuick
import QtQuick.Controls.Basic
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
    color: Theme.surface
    onVisibleChanged: if (visible) Capture.floatWindow(title, 600, 168)
    onClosing: Capture.closeMain()

    readonly property var modes: [
        { value: "rectangle", icon: "rectangle_landscape_regular", tooltip: qsTr("Rectangle") },
        { value: "window", icon: "window_regular", tooltip: qsTr("Window") },
        { value: "fullscreen", icon: "full_screen_maximize_regular", tooltip: qsTr("Full screen") },
        { value: "freeform", icon: "lasso_regular", tooltip: qsTr("Freeform") }
    ]
    readonly property var delays: [0, 3, 5, 10]

    Shortcut {
        sequences: ["Ctrl+N"]
        onActivated: Capture.start(window.purpose)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 8

            IconButton {
                variant: "accent"
                icon: "add_regular"
                text: qsTr("New")
                tooltip: qsTr("New snip (Ctrl+N)")
                onClicked: Capture.start(window.purpose)
            }

            Segmented {
                iconOnly: true
                options: [
                    { value: "snip", icon: "camera_regular", tooltip: qsTr("Snip") },
                    { value: "record", icon: "video_regular", tooltip: qsTr("Record") }
                ]
                current: window.purpose
                onPicked: value => {
                    window.purpose = value
                    if (value === "record" && Capture.mode === "freeform") Capture.mode = "rectangle"
                }
                Accessible.name: qsTr("Capture type")
            }

            Segmented {
                iconOnly: true
                options: window.modes.filter(mode => !(window.purpose === "record" && mode.value === "freeform"))
                current: Capture.mode
                onPicked: value => Capture.mode = value
                Accessible.name: qsTr("Snipping mode")
            }

            Dropdown {
                Layout.preferredWidth: 124
                model: window.delays.map(seconds => ({ value: seconds, label: seconds === 0 ? qsTr("No delay") : qsTr("%1 s delay").arg(seconds) }))
                current: Config.delay
                onActivated: Config.delay = currentValue
                Accessible.name: qsTr("Delay")
            }

            Item { Layout.fillWidth: true }

            IconButton {
                icon: "more_horizontal_regular"
                tooltip: menu.visible ? "" : qsTr("More")
                onClicked: menu.open()
                PopupMenu {
                    id: menu
                    x: parent.width - width
                    y: parent.height + 4
                    Action { text: qsTr("Settings"); onTriggered: Capture.showSettings() }
                    Action { text: qsTr("Open last capture"); enabled: Capture.resultPath.length > 0; onTriggered: Capture.showSnip() }
                    MenuDivider {}
                    Action { text: qsTr("Quit SnipShot"); onTriggered: Capture.quit() }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.outlineVariant
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            text: Capture.state === "idle" || Capture.status.length === 0
                ? (window.purpose === "record"
                    ? qsTr("Select New to record an area of your screen. Bind \"snipshot record\" to a key to start recording from anywhere.")
                    : qsTr("Pick a mode, then select New. Bind \"snipshot snip\" to a key, like Super+Shift+S, to snip from anywhere."))
                : Capture.status
            wrapMode: Text.Wrap
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSize
            verticalAlignment: Text.AlignVCenter
        }
    }
}
